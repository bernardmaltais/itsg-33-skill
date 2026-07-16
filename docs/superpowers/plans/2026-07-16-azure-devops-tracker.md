# Azure DevOps Tracker Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `tracker: azure-devops` as a third tracker mode to `itsg-33-assess` and `itsg-33-remediate` (alongside `github`/`local`), and replace every inline `gh`/`az` command in both skills with calls to dedicated, tested bash scripts.

**Architecture:** Six small bash scripts (`gh-list-tagged-issues.sh`, `gh-create-issue.sh`, `gh-create-pr.sh`, `ado-list-tagged-items.sh`, `ado-create-work-item.sh`, `ado-create-pr.sh`) each wrap one CLI operation with a fixed argument shape, `set -euo pipefail` strictness, and a single-line stderr reason on failure. Four of the six are used by both skills and are duplicated verbatim into each skill's own `scripts/` folder for portability; two (`gh-create-pr.sh`, `ado-create-pr.sh`) are remediate-only. `SKILL.md` in each skill is edited to invoke these scripts instead of constructing commands inline.

**Tech Stack:** Bash (`set -euo pipefail`), Python 3 (JSON parsing inside scripts, already a hard dependency elsewhere in this repo), `unittest` for tests (matching `test_write_fragment.py`'s existing convention — no pytest config exists in this repo).

## Global Constraints

- Every script starts with `set -euo pipefail`.
- Every script prints `==> ...` progress lines to **stderr**, never stdout.
- On failure, a script exits non-zero and prints exactly one line to stderr naming what went wrong (e.g. `gh-create-issue: gh issue create failed: <raw gh stderr>`) — never a stack trace or multi-line dump.
- On success, a script prints **only** the value(s) the calling `SKILL.md` step needs next (an ID, a URL, or a JSON array) to stdout — no extra chatter.
- Scripts take positional args only (no flags), validated with `${N:?usage message}` so a missing arg fails immediately with a usage string.
- No script handles authentication itself — each assumes an already-active `gh auth login` / `az login` session and lets the underlying CLI's own auth error surface verbatim.
- Tests use Python's `unittest` (subprocess-invoking the bash script with a stub `gh`/`az` binary prepended onto `PATH`), matching the existing `test_write_fragment.py` / `test_merge_state.py` convention — run directly with `python3 <test-file>.py`, no pytest config in this repo.
- Spec reference: `docs/superpowers/specs/2026-07-16-azure-devops-tracker-design.md`.

---

## File Structure

**Create:**
- `skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh` + `test_gh_list_tagged_issues.py`
- `skills/itsg-33-assess/scripts/gh-create-issue.sh` + `test_gh_create_issue.py`
- `skills/itsg-33-assess/scripts/ado-list-tagged-items.sh` + `test_ado_list_tagged_items.py`
- `skills/itsg-33-assess/scripts/ado-create-work-item.sh` + `test_ado_create_work_item.py`
- `skills/itsg-33-remediate/scripts/gh-list-tagged-issues.sh` + `test_gh_list_tagged_issues.py` (copy of the above)
- `skills/itsg-33-remediate/scripts/gh-create-issue.sh` + `test_gh_create_issue.py` (copy of the above)
- `skills/itsg-33-remediate/scripts/ado-list-tagged-items.sh` + `test_ado_list_tagged_items.py` (copy of the above)
- `skills/itsg-33-remediate/scripts/ado-create-work-item.sh` + `test_ado_create_work_item.py` (copy of the above)
- `skills/itsg-33-remediate/scripts/gh-create-pr.sh` + `test_gh_create_pr.py`
- `skills/itsg-33-remediate/scripts/ado-create-pr.sh` + `test_ado_create_pr.py`

**Modify:**
- `skills/itsg-33-assess/SKILL.md` — Init Steps 3-4 (tracker detection + config fields), Step 6 (gap issue creation)
- `skills/itsg-33-remediate/SKILL.md` — Step 1 (load gaps), Step 4 (needs-test task), Step 8 (open PR)

---

### Task 1: `gh-list-tagged-issues.sh`

**Files:**
- Create: `skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh`
- Test: `skills/itsg-33-assess/scripts/test_gh_list_tagged_issues.py`

**Interfaces:**
- Produces: `gh-list-tagged-issues.sh <label>` → prints the raw JSON array from `gh issue list --label <label> --state open --json number,title,body,labels` to stdout on success; exits non-zero with a one-line stderr reason on failure.

- [ ] **Step 1: Write the failing test**

```python
import json
import os
import stat
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "gh-list-tagged-issues.sh"


class GhListTaggedIssuesTest(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()

    def _stub_gh(self, body):
        path = self.bin_dir / "gh"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args, env_extra=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        if env_extra:
            env.update(env_extra)
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def test_success_prints_gh_output(self):
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "issue" && "$2" == "list" && "$4" == "itsg-33:gap" ]]; then\n'
            "  echo '[{\"number\": 1, \"title\": \"[itsg-33:gap] AC-2 — Account Management\"}]'\n"
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(["itsg-33:gap"])
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data[0]["number"], 1)

    def test_gh_failure_surfaces_reason(self):
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            'echo "error: not authenticated" >&2\n'
            "exit 1\n"
        )
        result = self._run(["itsg-33:gap"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("gh issue list failed", result.stderr)

    def test_missing_arg_fails_fast(self):
        result = self._run([])
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-assess/scripts/test_gh_list_tagged_issues.py -v`
Expected: FAIL — `gh-list-tagged-issues.sh` does not exist yet (`bash: cannot open ...`).

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# gh-list-tagged-issues.sh — List open GitHub issues carrying a given label.
#
# Usage: gh-list-tagged-issues.sh <label>
#
# Wraps: gh issue list --label <label> --state open --json number,title,body,labels
# Prints the raw JSON array to stdout on success.

set -euo pipefail

LABEL="${1:?Usage: gh-list-tagged-issues.sh <label>}"

echo "==> Listing open issues labelled '${LABEL}'..." >&2

if ! OUTPUT=$(gh issue list --label "$LABEL" --state open --json number,title,body,labels 2>&1); then
  echo "gh-list-tagged-issues: gh issue list failed: ${OUTPUT}" >&2
  exit 1
fi

echo "$OUTPUT"
```

Make it executable: `chmod +x skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-assess/scripts/test_gh_list_tagged_issues.py -v`
Expected: all 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh skills/itsg-33-assess/scripts/test_gh_list_tagged_issues.py
git commit -m "Add gh-list-tagged-issues.sh helper script"
```

---

### Task 2: `gh-create-issue.sh`

**Files:**
- Create: `skills/itsg-33-assess/scripts/gh-create-issue.sh`
- Test: `skills/itsg-33-assess/scripts/test_gh_create_issue.py`

**Interfaces:**
- Produces: `gh-create-issue.sh <title> <labels> <body-file>` (labels comma-separated, e.g. `"itsg-33:gap,P1"`) → prints `"<number> <url>"` to stdout on success.

- [ ] **Step 1: Write the failing test**

```python
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "gh-create-issue.sh"


class GhCreateIssueTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()
        self.body_file = Path(self.tmpdir.name) / "body.md"
        self.body_file.write_text("Control ID: AC-2\nFinding: Fail\n")

    def _stub_gh(self, body):
        path = self.bin_dir / "gh"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def test_success_prints_number_and_url(self):
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "issue" && "$2" == "create" ]]; then\n'
            '  echo "https://github.com/acme/repo/issues/42"\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(
            ["[itsg-33:gap] AC-2 — Account Management", "itsg-33:gap,P1", str(self.body_file)]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "42 https://github.com/acme/repo/issues/42")

    def test_passes_each_label_separately(self):
        capture_file = Path(self.tmpdir.name) / "captured_args"
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            f'echo "$@" > {capture_file}\n'
            'echo "https://github.com/acme/repo/issues/1"\n'
            "exit 0\n"
        )
        self._run(["title", "itsg-33:gap,P1", str(self.body_file)])
        captured = capture_file.read_text()
        self.assertIn("--label itsg-33:gap", captured)
        self.assertIn("--label P1", captured)

    def test_missing_body_file_fails(self):
        result = self._run(["title", "itsg-33:gap,P1", "/no/such/file.md"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("body file not found", result.stderr)

    def test_gh_failure_surfaces_reason(self):
        self._stub_gh('#!/usr/bin/env bash\necho "rate limited" >&2\nexit 1\n')
        result = self._run(["title", "itsg-33:gap,P1", str(self.body_file)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("gh issue create failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-assess/scripts/test_gh_create_issue.py -v`
Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# gh-create-issue.sh — Create a GitHub issue with one or more labels.
#
# Usage: gh-create-issue.sh <title> <labels> <body-file>
#   <labels> is a comma-separated list, e.g. "itsg-33:gap,P1"
#
# Wraps: gh issue create --title <title> --label <l1> [--label <l2> ...] --body-file <body-file>
# Prints "<number> <url>" to stdout on success.

set -euo pipefail

TITLE="${1:?Usage: gh-create-issue.sh <title> <labels> <body-file>}"
LABELS="${2:?Usage: gh-create-issue.sh <title> <labels> <body-file>}"
BODY_FILE="${3:?Usage: gh-create-issue.sh <title> <labels> <body-file>}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "gh-create-issue: body file not found: ${BODY_FILE}" >&2
  exit 1
fi

LABEL_ARGS=()
IFS=',' read -ra LABEL_LIST <<< "$LABELS"
for label in "${LABEL_LIST[@]}"; do
  LABEL_ARGS+=(--label "$label")
done

echo "==> Creating issue '${TITLE}'..." >&2

if ! URL=$(gh issue create --title "$TITLE" "${LABEL_ARGS[@]}" --body-file "$BODY_FILE" 2>&1); then
  echo "gh-create-issue: gh issue create failed: ${URL}" >&2
  exit 1
fi

NUMBER="${URL##*/}"
echo "${NUMBER} ${URL}"
```

Make it executable: `chmod +x skills/itsg-33-assess/scripts/gh-create-issue.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-assess/scripts/test_gh_create_issue.py -v`
Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/scripts/gh-create-issue.sh skills/itsg-33-assess/scripts/test_gh_create_issue.py
git commit -m "Add gh-create-issue.sh helper script"
```

---

### Task 3: `ado-list-tagged-items.sh`

**Files:**
- Create: `skills/itsg-33-assess/scripts/ado-list-tagged-items.sh`
- Test: `skills/itsg-33-assess/scripts/test_ado_list_tagged_items.py`

**Interfaces:**
- Produces: `ado-list-tagged-items.sh <org> <project> <tag>` → prints a JSON array of `{"id": <int>, "title": <string>}` objects to stdout on success.

- [ ] **Step 1: Write the failing test**

```python
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "ado-list-tagged-items.sh"


class AdoListTaggedItemsTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()

    def _stub_az(self, body):
        path = self.bin_dir / "az"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args, env_extra=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        if env_extra:
            env.update(env_extra)
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def test_success_when_extension_already_installed(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "boards" && "$2" == "query" ]]; then\n'
            '  echo \'[{"id": 101, "fields": {"System.Title": "[itsg-33:gap] AC-2 — Account Management"}}]\'\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(["https://dev.azure.com/acme", "MyProject", "itsg-33:gap"])
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data, [{"id": 101, "title": "[itsg-33:gap] AC-2 — Account Management"}])

    def test_installs_extension_when_missing(self):
        marker = Path(self.tmpdir.name) / "installed"
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "extension" && "$2" == "add" ]]; then\n'
            f'  touch "{marker}"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "boards" && "$2" == "query" ]]; then\n'
            "  echo '[]'\n"
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(["https://dev.azure.com/acme", "MyProject", "itsg-33:gap"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists())

    def test_az_query_failure_surfaces_reason(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'echo "TF400898: unauthorized" >&2\n'
            "exit 1\n"
        )
        result = self._run(["https://dev.azure.com/acme", "MyProject", "itsg-33:gap"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("az boards query failed", result.stderr)

    def test_missing_arg_fails_fast(self):
        result = self._run(["https://dev.azure.com/acme"])
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-assess/scripts/test_ado_list_tagged_items.py -v`
Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# ado-list-tagged-items.sh — List open Azure DevOps work items carrying a given tag.
#
# Usage: ado-list-tagged-items.sh <org> <project> <tag>
#
# Wraps: az boards query --wiql "..." for open items tagged <tag>.
# Prints a JSON array of {"id": <int>, "title": <string>} objects to stdout on success.

set -euo pipefail

ORG="${1:?Usage: ado-list-tagged-items.sh <org> <project> <tag>}"
PROJECT="${2:?Usage: ado-list-tagged-items.sh <org> <project> <tag>}"
TAG="${3:?Usage: ado-list-tagged-items.sh <org> <project> <tag>}"

if ! az extension list -o tsv --query "[?name=='azure-devops'].name" 2>/dev/null | grep -q azure-devops; then
  echo "==> Installing azure-devops CLI extension..." >&2
  az extension add --name azure-devops -y >&2
fi

WIQL="SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '${PROJECT}' AND [System.Tags] CONTAINS '${TAG}' AND [System.State] <> 'Closed' AND [System.State] <> 'Removed'"

echo "==> Querying work items tagged '${TAG}'..." >&2

if ! RAW=$(az boards query --org "$ORG" --wiql "$WIQL" -o json 2>&1); then
  echo "ado-list-tagged-items: az boards query failed: ${RAW}" >&2
  exit 1
fi

python3 -c "
import json, sys
d = json.loads(sys.argv[1])
items = d if isinstance(d, list) else d.get('workItems', [])
out = [{'id': i['id'], 'title': i['fields']['System.Title']} for i in items]
print(json.dumps(out))
" "$RAW"
```

Make it executable: `chmod +x skills/itsg-33-assess/scripts/ado-list-tagged-items.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-assess/scripts/test_ado_list_tagged_items.py -v`
Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/scripts/ado-list-tagged-items.sh skills/itsg-33-assess/scripts/test_ado_list_tagged_items.py
git commit -m "Add ado-list-tagged-items.sh helper script"
```

---

### Task 4: `ado-create-work-item.sh`

**Files:**
- Create: `skills/itsg-33-assess/scripts/ado-create-work-item.sh`
- Test: `skills/itsg-33-assess/scripts/test_ado_create_work_item.py`

**Interfaces:**
- Produces: `ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>` (tags semicolon-separated, e.g. `"itsg-33:gap; P1"`) → prints `"<id> <url>"` to stdout on success.

- [ ] **Step 1: Write the failing test**

```python
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "ado-create-work-item.sh"


class AdoCreateWorkItemTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()
        self.desc_file = Path(self.tmpdir.name) / "desc.html"
        self.desc_file.write_text("<p>Finding: Fail</p>")

    def _stub_az(self, body):
        path = self.bin_dir / "az"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def test_success_prints_id_and_url(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "boards" && "$2" == "work-item" && "$3" == "create" ]]; then\n'
            '  echo \'{"id": 555}\'\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(
            [
                "https://dev.azure.com/acme",
                "MyProject",
                "Issue",
                "[itsg-33:gap] AC-2 — Account Management",
                "itsg-33:gap; P1",
                str(self.desc_file),
            ]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "555 https://dev.azure.com/acme/MyProject/_workitems/edit/555",
        )

    def test_missing_description_file_fails(self):
        result = self._run(
            [
                "https://dev.azure.com/acme",
                "MyProject",
                "Issue",
                "title",
                "itsg-33:gap; P1",
                "/no/such/file.html",
            ]
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("description file not found", result.stderr)

    def test_az_failure_surfaces_reason(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'echo "VS402625: work item type does not exist" >&2\n'
            "exit 1\n"
        )
        result = self._run(
            [
                "https://dev.azure.com/acme",
                "MyProject",
                "Issue",
                "title",
                "itsg-33:gap; P1",
                str(self.desc_file),
            ]
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("az boards work-item create failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-assess/scripts/test_ado_create_work_item.py -v`
Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# ado-create-work-item.sh — Create an Azure DevOps work item with tags.
#
# Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>
#   <tags> is a semicolon-separated string, e.g. "itsg-33:gap; P1"
#
# Wraps: az boards work-item create --type <type> --title <title> \
#          --description <html> --fields "System.Tags=<tags>"
# Prints "<id> <url>" to stdout on success.

set -euo pipefail

ORG="${1:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"
PROJECT="${2:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"
TYPE="${3:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"
TITLE="${4:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"
TAGS="${5:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"
DESCRIPTION_FILE="${6:?Usage: ado-create-work-item.sh <org> <project> <type> <title> <tags> <description-file>}"

if [[ ! -f "$DESCRIPTION_FILE" ]]; then
  echo "ado-create-work-item: description file not found: ${DESCRIPTION_FILE}" >&2
  exit 1
fi

if ! az extension list -o tsv --query "[?name=='azure-devops'].name" 2>/dev/null | grep -q azure-devops; then
  echo "==> Installing azure-devops CLI extension..." >&2
  az extension add --name azure-devops -y >&2
fi

DESCRIPTION=$(cat "$DESCRIPTION_FILE")

echo "==> Creating work item '${TITLE}'..." >&2

if ! RAW=$(az boards work-item create \
  --org "$ORG" \
  --project "$PROJECT" \
  --type "$TYPE" \
  --title "$TITLE" \
  --description "$DESCRIPTION" \
  --fields "System.Tags=${TAGS}" \
  -o json 2>&1); then
  echo "ado-create-work-item: az boards work-item create failed: ${RAW}" >&2
  exit 1
fi

python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d['id'], '${ORG}/${PROJECT}/_workitems/edit/' + str(d['id']))
" "$RAW"
```

Make it executable: `chmod +x skills/itsg-33-assess/scripts/ado-create-work-item.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-assess/scripts/test_ado_create_work_item.py -v`
Expected: all 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/scripts/ado-create-work-item.sh skills/itsg-33-assess/scripts/test_ado_create_work_item.py
git commit -m "Add ado-create-work-item.sh helper script"
```

---

### Task 5: Duplicate the four shared scripts into `itsg-33-remediate/scripts/`

**Files:**
- Create: `skills/itsg-33-remediate/scripts/gh-list-tagged-issues.sh`, `test_gh_list_tagged_issues.py`
- Create: `skills/itsg-33-remediate/scripts/gh-create-issue.sh`, `test_gh_create_issue.py`
- Create: `skills/itsg-33-remediate/scripts/ado-list-tagged-items.sh`, `test_ado_list_tagged_items.py`
- Create: `skills/itsg-33-remediate/scripts/ado-create-work-item.sh`, `test_ado_create_work_item.py`

**Interfaces:**
- Consumes: the four scripts + tests created in Tasks 1-4, byte-for-byte.
- Produces: nothing new — `itsg-33-remediate/scripts/` becomes self-contained for these four operations, matching the spec's portability requirement (each skill folder can be copied out standalone).

`itsg-33-remediate` needs these four scripts too: Step 1 uses the two `list` scripts, Step 4 uses the two `create` scripts (for the needs-test task).

- [ ] **Step 1: Create the target directory and copy the files**

```bash
mkdir -p skills/itsg-33-remediate/scripts
for f in gh-list-tagged-issues.sh test_gh_list_tagged_issues.py \
         gh-create-issue.sh test_gh_create_issue.py \
         ado-list-tagged-items.sh test_ado_list_tagged_items.py \
         ado-create-work-item.sh test_ado_create_work_item.py; do
  cp "skills/itsg-33-assess/scripts/$f" "skills/itsg-33-remediate/scripts/$f"
done
chmod +x skills/itsg-33-remediate/scripts/*.sh
```

- [ ] **Step 2: Verify the copies are byte-identical**

Run: `diff -r skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh skills/itsg-33-remediate/scripts/gh-list-tagged-issues.sh && diff -r skills/itsg-33-assess/scripts/gh-create-issue.sh skills/itsg-33-remediate/scripts/gh-create-issue.sh && diff -r skills/itsg-33-assess/scripts/ado-list-tagged-items.sh skills/itsg-33-remediate/scripts/ado-list-tagged-items.sh && diff -r skills/itsg-33-assess/scripts/ado-create-work-item.sh skills/itsg-33-remediate/scripts/ado-create-work-item.sh`
Expected: no output (files identical), exit code 0.

- [ ] **Step 3: Run the copied tests from their new location**

```bash
python3 skills/itsg-33-remediate/scripts/test_gh_list_tagged_issues.py -v
python3 skills/itsg-33-remediate/scripts/test_gh_create_issue.py -v
python3 skills/itsg-33-remediate/scripts/test_ado_list_tagged_items.py -v
python3 skills/itsg-33-remediate/scripts/test_ado_create_work_item.py -v
```

Expected: all PASS (each test file resolves its script via `Path(__file__).parent`, so it exercises the copy in its own directory).

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-remediate/scripts/
git commit -m "Duplicate shared gh/ado helper scripts into itsg-33-remediate"
```

---

### Task 6: `gh-create-pr.sh`

**Files:**
- Create: `skills/itsg-33-remediate/scripts/gh-create-pr.sh`
- Test: `skills/itsg-33-remediate/scripts/test_gh_create_pr.py`

**Interfaces:**
- Produces: `gh-create-pr.sh <title> <body-file> [<closes-issue-number>]` → prints the PR URL to stdout on success. When `<closes-issue-number>` is given, appends `Closes #<N>` to the body before creating the PR.

- [ ] **Step 1: Write the failing test**

```python
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "gh-create-pr.sh"


class GhCreatePrTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()
        self.body_file = Path(self.tmpdir.name) / "body.md"
        self.body_file.write_text("## Control\nAC-2\n")
        self.captured_body = Path(self.tmpdir.name) / "captured_body.md"

    def _stub_gh(self, body):
        path = self.bin_dir / "gh"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        env["STUB_CAPTURED_BODY"] = str(self.captured_body)
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def test_success_without_closes_number(self):
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "pr" && "$2" == "create" ]]; then\n'
            '  echo "https://github.com/acme/repo/pull/9"\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(["fix(AC-2): title", str(self.body_file)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "https://github.com/acme/repo/pull/9")

    def test_appends_closes_line_when_given(self):
        self._stub_gh(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "pr" && "$2" == "create" ]]; then\n'
            '  prev=""\n'
            '  for arg in "$@"; do\n'
            '    if [[ "$prev" == "--body-file" ]]; then\n'
            '      cp "$arg" "$STUB_CAPTURED_BODY"\n'
            "    fi\n"
            '    prev="$arg"\n'
            "  done\n"
            '  echo "https://github.com/acme/repo/pull/9"\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(["fix(AC-2): title", str(self.body_file), "7"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Closes #7", self.captured_body.read_text())

    def test_missing_body_file_fails(self):
        result = self._run(["title", "/no/such/file.md"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("body file not found", result.stderr)

    def test_gh_failure_surfaces_reason(self):
        self._stub_gh('#!/usr/bin/env bash\necho "no such branch" >&2\nexit 1\n')
        result = self._run(["title", str(self.body_file)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("gh pr create failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-remediate/scripts/test_gh_create_pr.py -v`
Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# gh-create-pr.sh — Open a draft GitHub PR, optionally closing a gap issue.
#
# Usage: gh-create-pr.sh <title> <body-file> [<closes-issue-number>]
#
# Wraps: gh pr create --draft --title <title> --body-file <file>
# When <closes-issue-number> is given, appends "Closes #<N>" to the body
# before creating the PR. Prints the PR URL to stdout on success.

set -euo pipefail

TITLE="${1:?Usage: gh-create-pr.sh <title> <body-file> [<closes-issue-number>]}"
BODY_FILE="${2:?Usage: gh-create-pr.sh <title> <body-file> [<closes-issue-number>]}"
CLOSES_NUMBER="${3:-}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "gh-create-pr: body file not found: ${BODY_FILE}" >&2
  exit 1
fi

FINAL_BODY_FILE="$BODY_FILE"
if [[ -n "$CLOSES_NUMBER" ]]; then
  FINAL_BODY_FILE=$(mktemp)
  trap 'rm -f "$FINAL_BODY_FILE"' EXIT
  cat "$BODY_FILE" > "$FINAL_BODY_FILE"
  printf '\nCloses #%s\n' "$CLOSES_NUMBER" >> "$FINAL_BODY_FILE"
fi

echo "==> Creating draft PR '${TITLE}'..." >&2

if ! URL=$(gh pr create --draft --title "$TITLE" --body-file "$FINAL_BODY_FILE" 2>&1); then
  echo "gh-create-pr: gh pr create failed: ${URL}" >&2
  exit 1
fi

echo "$URL"
```

Make it executable: `chmod +x skills/itsg-33-remediate/scripts/gh-create-pr.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-remediate/scripts/test_gh_create_pr.py -v`
Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-remediate/scripts/gh-create-pr.sh skills/itsg-33-remediate/scripts/test_gh_create_pr.py
git commit -m "Add gh-create-pr.sh helper script"
```

---

### Task 7: `ado-create-pr.sh`

**Files:**
- Create: `skills/itsg-33-remediate/scripts/ado-create-pr.sh`
- Test: `skills/itsg-33-remediate/scripts/test_ado_create_pr.py`

**Interfaces:**
- Produces: `ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]` → prints `"<id> <url>"` to stdout on success. When `<target-branch>` is omitted, auto-detects the repo's default branch via `az repos show`.

- [ ] **Step 1: Write the failing test**

```python
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "ado-create-pr.sh"


class AdoCreatePrTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.bin_dir = Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()
        self.body_file = Path(self.tmpdir.name) / "body.md"
        self.body_file.write_text("## Control\nAC-2\n")

    def _stub_az(self, body):
        path = self.bin_dir / "az"
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    def _run(self, args):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True
        )

    def _common_args(self, target_branch=None):
        args = [
            "https://dev.azure.com/acme",
            "MyProject",
            "myrepo",
            "itsg33/fix/AC-2",
            "fix(AC-2): title",
            str(self.body_file),
            "555",
        ]
        if target_branch:
            args.append(target_branch)
        return args

    def test_auto_detects_default_branch_when_omitted(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "repos" && "$2" == "show" ]]; then\n'
            '  echo "refs/heads/main"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "repos" && "$2" == "pr" && "$3" == "create" ]]; then\n'
            '  echo \'{"pullRequestId": 77}\'\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(self._common_args())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "77 https://dev.azure.com/acme/MyProject/_git/myrepo/pullrequest/77",
        )

    def test_skips_default_branch_detection_when_given(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "repos" && "$2" == "show" ]]; then\n'
            '  echo "SHOULD NOT BE CALLED" >&2\n'
            "  exit 1\n"
            "fi\n"
            'if [[ "$1" == "repos" && "$2" == "pr" && "$3" == "create" ]]; then\n'
            '  echo \'{"pullRequestId": 77}\'\n'
            "  exit 0\n"
            "fi\n"
            "exit 1\n"
        )
        result = self._run(self._common_args(target_branch="develop"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_body_file_fails(self):
        args = self._common_args()
        args[5] = "/no/such/file.md"
        result = self._run(args)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("body file not found", result.stderr)

    def test_az_pr_create_failure_surfaces_reason(self):
        self._stub_az(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "extension" && "$2" == "list" ]]; then\n'
            '  echo "azure-devops"\n'
            "  exit 0\n"
            "fi\n"
            'if [[ "$1" == "repos" && "$2" == "show" ]]; then\n'
            '  echo "refs/heads/main"\n'
            "  exit 0\n"
            "fi\n"
            'echo "TF401398: policy required" >&2\n'
            "exit 1\n"
        )
        result = self._run(self._common_args())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("az repos pr create failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 skills/itsg-33-remediate/scripts/test_ado_create_pr.py -v`
Expected: FAIL — script does not exist yet.

- [ ] **Step 3: Write the implementation**

```bash
#!/usr/bin/env bash
# ado-create-pr.sh — Open a draft Azure DevOps PR linked to a work item.
#
# Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]
#   When <target-branch> is omitted, the repo's default branch is auto-detected.
#
# Wraps: az repos pr create --draft --work-items <work-item-id>
# Prints "<id> <url>" to stdout on success.

set -euo pipefail

ORG="${1:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
PROJECT="${2:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
REPO="${3:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
SOURCE_BRANCH="${4:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
TITLE="${5:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
BODY_FILE="${6:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
WORK_ITEM_ID="${7:?Usage: ado-create-pr.sh <org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]}"
TARGET_BRANCH="${8:-}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "ado-create-pr: body file not found: ${BODY_FILE}" >&2
  exit 1
fi

if ! az extension list -o tsv --query "[?name=='azure-devops'].name" 2>/dev/null | grep -q azure-devops; then
  echo "==> Installing azure-devops CLI extension..." >&2
  az extension add --name azure-devops -y >&2
fi

if [[ -z "$TARGET_BRANCH" ]]; then
  echo "==> Detecting default branch for ${REPO}..." >&2
  if ! TARGET_BRANCH=$(az repos show --org "$ORG" --project "$PROJECT" --repository "$REPO" --query defaultBranch -o tsv 2>&1); then
    echo "ado-create-pr: az repos show failed: ${TARGET_BRANCH}" >&2
    exit 1
  fi
  TARGET_BRANCH="${TARGET_BRANCH#refs/heads/}"
fi

DESCRIPTION=$(cat "$BODY_FILE")

echo "==> Creating draft PR '${TITLE}' (${SOURCE_BRANCH} -> ${TARGET_BRANCH})..." >&2

if ! RAW=$(az repos pr create \
  --org "$ORG" \
  --project "$PROJECT" \
  --repository "$REPO" \
  --source-branch "$SOURCE_BRANCH" \
  --target-branch "$TARGET_BRANCH" \
  --title "$TITLE" \
  --description "$DESCRIPTION" \
  --work-items "$WORK_ITEM_ID" \
  --draft \
  -o json 2>&1); then
  echo "ado-create-pr: az repos pr create failed: ${RAW}" >&2
  exit 1
fi

python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d['pullRequestId'], '${ORG}/${PROJECT}/_git/${REPO}/pullrequest/' + str(d['pullRequestId']))
" "$RAW"
```

Make it executable: `chmod +x skills/itsg-33-remediate/scripts/ado-create-pr.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 skills/itsg-33-remediate/scripts/test_ado_create_pr.py -v`
Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-remediate/scripts/ado-create-pr.sh skills/itsg-33-remediate/scripts/test_ado_create_pr.py
git commit -m "Add ado-create-pr.sh helper script"
```

---

### Task 8: Update `itsg-33-assess/SKILL.md`

**Files:**
- Modify: `skills/itsg-33-assess/SKILL.md` (Init branch Steps 3-4; Assess branch Step 6)

**Interfaces:**
- Consumes: `gh-list-tagged-issues.sh`, `gh-create-issue.sh`, `ado-list-tagged-items.sh`, `ado-create-work-item.sh` (Tasks 1-4), by their exact CLI shapes documented above.

There is no test cycle for `SKILL.md` prose (it's agent instructions, not executable code — see the design spec's Verification Plan). Verification for this task is a diff read-through against the checklist in Step 3 below.

- [ ] **Step 1: Replace Init Step 3 (tracker detection)**

In `skills/itsg-33-assess/SKILL.md`, find:

```markdown
3. **Detect** tracker mode: GitHub remote present → `github`; absent → `local`.
```

Replace with:

```markdown
3. **Detect** tracker mode from `git remote -v`:

   | Remote contains | `tracker` |
   |---|---|
   | `github.com` | `github` |
   | `dev.azure.com` | `azure-devops` |
   | neither | `local` |
```

- [ ] **Step 2: Replace Init Step 4 (config fields)**

Find:

```markdown
4. **Write** `security/itsg33.yaml`:
   ```yaml
   profile: PBMM
   system_name: <value>
   system_boundary: <value>
   tracker: <github | local>
   ```
   Completion: file exists and all four fields are populated.
```

Replace with:

```markdown
4. **Write** `security/itsg33.yaml`:
   ```yaml
   profile: PBMM
   system_name: <value>
   system_boundary: <value>
   tracker: <github | azure-devops | local>
   ```
   For `tracker: azure-devops` only, also write `ado_org`, `ado_project`, `ado_repo`, parsed
   from the remote URL:
   - HTTPS form: `https://[<user>@]dev.azure.com/<org>/<project>/_git/<repo>`
   - SSH form: `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`

   ```yaml
   ado_org: https://dev.azure.com/<org>
   ado_project: <project>
   ado_repo: <repo>
   ```

   Completion: file exists, all four base fields are populated, and (for `tracker:
   azure-devops`) `ado_org`/`ado_project`/`ado_repo` are also populated.
```

- [ ] **Step 3: Replace Assess Step 6 (create gap issues)**

Find the entire `### Step 6 — Create gap issues` section and replace with:

```markdown
### Step 6 — Create gap issues

For each **Fail** finding, create a gap issue only if no open gap already exists for
that control.

**GitHub mode** (`tracker: github`):
```bash
bash skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh itsg-33:gap
```
- Skip creation if a returned issue's title matches `[itsg-33:gap] <Control ID> — <Control Name>`.
- Otherwise, write the issue body (control ID, finding, confidence note, recommended action,
  link to evidence card) to a scratch file, then:
```bash
bash skills/itsg-33-assess/scripts/gh-create-issue.sh \
  "[itsg-33:gap] <Control ID> — <Control Name>" \
  "itsg-33:gap,<P1|P2|P3>" \
  <body-file>
```

**Azure DevOps mode** (`tracker: azure-devops`):
```bash
bash skills/itsg-33-assess/scripts/ado-list-tagged-items.sh "<ado_org>" "<ado_project>" itsg-33:gap
```
- Skip creation if a returned item's title matches `[itsg-33:gap] <Control ID> — <Control Name>`.
- Otherwise, write the description as simple HTML (`<p>`, `<ul>`, `<code>` — `System.Description`
  is a rich-text HTML field, not Markdown) with the same fields, then:
```bash
bash skills/itsg-33-assess/scripts/ado-create-work-item.sh \
  "<ado_org>" "<ado_project>" Issue \
  "[itsg-33:gap] <Control ID> — <Control Name>" \
  "itsg-33:gap; <P1|P2|P3>" \
  <description-file>
```

**Local mode** (`tracker: local`):
- Write `security/gaps/<control-id>.md` with the same fields.
- Skip if the file already exists.

If either script exits non-zero, its stderr names exactly what went wrong; report this to the
user rather than retrying silently.

Completion: every Fail finding has a gap issue, work item, or gap file; no duplicates created.
```

- [ ] **Step 4: Self-check**

Read the full modified `skills/itsg-33-assess/SKILL.md` and confirm:
- The tracker-detection table appears once, matches the spec's table exactly.
- Step 6 has three clearly separated mode branches (GitHub / Azure DevOps / Local), each showing exact script invocations with the arg order defined in Tasks 1-4.
- No leftover mention of a bare `gh issue list`/`gh issue create` command in Step 6.

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/SKILL.md
git commit -m "Wire itsg-33-assess into azure-devops tracker mode and gh/ado scripts"
```

---

### Task 9: Update `itsg-33-remediate/SKILL.md`

**Files:**
- Modify: `skills/itsg-33-remediate/SKILL.md` (Step 1; Step 4; Step 8)

**Interfaces:**
- Consumes: all six scripts from Tasks 1-2 and 5-7, by their exact CLI shapes.

- [ ] **Step 1: Replace Step 1 (load gap issues)**

Find the entire `### Step 1 — Load gap issues` section and replace with:

```markdown
### Step 1 — Load gap issues

Read `security/itsg33.yaml` to determine tracker mode.

**GitHub mode** (`tracker: github`):
```bash
bash skills/itsg-33-remediate/scripts/gh-list-tagged-issues.sh itsg-33:gap
```

**Azure DevOps mode** (`tracker: azure-devops`):
```bash
bash skills/itsg-33-remediate/scripts/ado-list-tagged-items.sh "<ado_org>" "<ado_project>" itsg-33:gap
```
For each returned `id`, fetch full field values:
```bash
az boards work-item show --id <id> --org "<ado_org>" -o json
```
Control ID/name are parsed from the title (`[itsg-33:gap] <Control ID> — <Control Name>` — the
same format `itsg-33-assess` used to create it). Source reference is the work item ID/URL
(`<ado_org>/<ado_project>/_workitems/edit/<id>`).

**Local mode** (`tracker: local`):
Read every file in `security/gaps/`, **excluding** files ending in
`-needs-test.md` — those are tasks created by a prior Step 4, not gaps.

For every open gap (any mode), also read its linked evidence card,
`security/evidence/<control-id>.md`. The evidence card — not the gap issue, work item, or gap
file — is the source of truth for **Severity**, since `evidence-card.md`'s
`**Severity:** <P1 | P2 | P3>` header field is the only place severity is
recorded in a form every tracker mode can read the same way (GitHub conveys it only via issue
label and Azure DevOps only via a tag, neither of which local mode has an equivalent of).

Build one record per gap with: control ID, control name, severity, finding,
confidence note, recommended action, evidence card path, and a source
reference (issue number, work item ID, or gap file path). Completion: every open gap
(possibly zero) is loaded into this common shape. If there are zero open gaps,
report "no open ITSG-33 gaps found" and stop — do not proceed to Step 2.
```

- [ ] **Step 2: Replace the needs-test branch of Step 4**

Find:

```markdown
**If no runner is found:** stop — do not propose or apply a fix for this gap.
Create a needs-test task instead:

- GitHub mode: open an Issue labelled `itsg-33:needs-test`, titled
  `[itsg-33:needs-test] <control-id> — write failing test`, with a body
  explaining the gap needs a test that fails against the current code before
  `itsg-33-remediate` can touch it.
- Local mode: write `security/gaps/<control-id>-needs-test.md` with the same
  content.
```

Replace with:

```markdown
**If no runner is found:** stop — do not propose or apply a fix for this gap.
Create a needs-test task instead:

- GitHub mode:
  ```bash
  bash skills/itsg-33-remediate/scripts/gh-create-issue.sh \
    "[itsg-33:needs-test] <control-id> — write failing test" \
    itsg-33:needs-test \
    <body-file>
  ```
  where `<body-file>` explains the gap needs a test that fails against the current code before
  `itsg-33-remediate` can touch it.
- Azure DevOps mode:
  ```bash
  bash skills/itsg-33-remediate/scripts/ado-create-work-item.sh \
    "<ado_org>" "<ado_project>" Issue \
    "[itsg-33:needs-test] <control-id> — write failing test" \
    itsg-33:needs-test \
    <description-file>
  ```
  with the same explanation, written as simple HTML.
- Local mode: write `security/gaps/<control-id>-needs-test.md` with the same
  content.
```

- [ ] **Step 3: Replace Step 8 (open draft PR)**

Find the entire `### Step 8 — Open draft PR` section and replace with:

```markdown
### Step 8 — Open draft PR

First, check whether a usable remote exists (the same check `itsg-33-assess` Step 1
uses to detect tracker mode):

```bash
git remote -v
```

**If no remote exists (`tracker: local`):** stop here — do not attempt to open a PR (there is
nothing to open one against). Tell the user: the fix is committed on branch
`itsg33/fix/<control-id>` with tests green, but no draft PR was opened because this repo has no
remote; push a remote and re-invoke this step (or open the PR manually) once one exists.
Completion (no-remote case): the branch and its green commit exist; the user has been told why no
PR was opened.

**If a remote exists:** proceed as below. Title: `fix(<control-id>): <control name> — <one-line summary>`.

Body (fully self-contained — the reviewer should need nothing else open):

```
## Control
<Control ID> — <Control Name> (PBMM <severity>)

## Finding
<finding + confidence note, from the evidence card>

## Fix
<rationale for the change just made>

## Test Results
**Before:** <Step 4 baseline>
**After:** <Step 7 result>

<closing line — see below>
```

The closing line depends on tracker mode:
- GitHub mode: `Closes #<gap-issue-number>`
- Azure DevOps mode: none — the PR is linked to the work item directly by the script (see
  below), not via a body keyword.
- Local mode: `Resolves local gap: security/gaps/<control-id>.md` — since
  there's no merge-triggered auto-close in local mode, follow it with a line
  asking the user to delete that file once this PR merges.

**GitHub mode:**
```bash
bash skills/itsg-33-remediate/scripts/gh-create-pr.sh "<title>" <body-file> <gap-issue-number>
```
The script appends the `Closes #<N>` line to the body itself.

**Azure DevOps mode:**
```bash
bash skills/itsg-33-remediate/scripts/ado-create-pr.sh \
  "<ado_org>" "<ado_project>" "<ado_repo>" \
  "<source-branch>" "<title>" <body-file> <work-item-id>
```
Target branch is omitted — the script auto-detects the repo's default branch. The script's
`az repos pr create --work-items` call links the gap work item in the same invocation; there is
no separate linking step. **Known limitation:** this links the PR to the work item but does not
by itself close the work item on merge — whether it auto-transitions depends on the org's own
branch-policy/completion settings, outside this skill's scope since it only ever creates a draft
PR. Treat this the same as local mode's manual-cleanup posture, not GitHub mode's automatic
`Closes #N` behavior.

**Local mode:** no script — there is nothing to open a PR against (handled by the no-remote
branch above).

Completion: a draft PR exists with the correct title format and every body
field populated (no field left as a placeholder).
```

- [ ] **Step 4: Self-check**

Read the full modified `skills/itsg-33-remediate/SKILL.md` and confirm:
- Step 1's three branches each match the exact script/CLI shape from Tasks 1, 5.
- Step 4's needs-test branches each match Tasks 2, 5.
- Step 8 has three branches (no-remote/local, GitHub, Azure DevOps) with no bare `gh pr create` left over.
- Step 9 (Update POA&M) still reads consistently with the new Step 8 wording — no edits needed there, but confirm it doesn't contradict the new text (it shouldn't; it already speaks generically of "Step 8 opened a PR").

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-remediate/SKILL.md
git commit -m "Wire itsg-33-remediate into azure-devops tracker mode and gh/ado scripts"
```

---

### Task 10: Final validation pass

**Files:** none created/modified — read-only verification across everything from Tasks 1-9.

- [ ] **Step 1: Syntax-check every new script**

```bash
for f in skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh \
         skills/itsg-33-assess/scripts/gh-create-issue.sh \
         skills/itsg-33-assess/scripts/ado-list-tagged-items.sh \
         skills/itsg-33-assess/scripts/ado-create-work-item.sh \
         skills/itsg-33-remediate/scripts/gh-list-tagged-issues.sh \
         skills/itsg-33-remediate/scripts/gh-create-issue.sh \
         skills/itsg-33-remediate/scripts/ado-list-tagged-items.sh \
         skills/itsg-33-remediate/scripts/ado-create-work-item.sh \
         skills/itsg-33-remediate/scripts/gh-create-pr.sh \
         skills/itsg-33-remediate/scripts/ado-create-pr.sh; do
  bash -n "$f" && echo "OK: $f"
done
```

Expected: `OK: <path>` printed for all 10 scripts, no syntax errors.

- [ ] **Step 2: Run every test file**

```bash
for f in skills/itsg-33-assess/scripts/test_*.py skills/itsg-33-remediate/scripts/test_*.py; do
  echo "=== $f ==="
  python3 "$f" -v
done
```

Expected: every suite reports all tests passing (`OK` at the end of `unittest` output).

- [ ] **Step 3: Confirm scripts are executable**

```bash
find skills/itsg-33-assess/scripts skills/itsg-33-remediate/scripts -name "*.sh" ! -perm -u+x
```

Expected: no output (every `.sh` file has the executable bit set).

- [ ] **Step 4: Confirm no unrelated files were touched**

```bash
git status --short
```

Expected: working tree clean (everything from Tasks 1-9 was already committed); no unexpected modifications outside the files listed in this plan's File Structure section.

No commit for this task — it's a read-only check. If any step fails, go back to the relevant earlier task and fix it there (with its own commit), then re-run this task's checks.
