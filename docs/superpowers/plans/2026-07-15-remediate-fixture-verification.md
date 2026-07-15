# Verify itsg-33-remediate Against the Fixture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run `itsg-33-remediate` end-to-end against a scratch copy of `test/fixtures/sample-app/`
for the AC-6 gap (issue #14), independently verify every step of the ten-step flow, and fix any
genuine, generalizable gaps found in `skills/itsg-33-remediate/SKILL.md`.

**Architecture:** A git-init'd `/tmp` scratch copy of the fixture (no GitHub remote → tracker
mode auto-detects `local`) gets a real AC-6 gap from a targeted, AC-family-only
`itsg-33-assess` dispatch (not a full 9-family run), then `itsg-33-remediate` is dispatched
against it and walked through Steps 1–10. A known discrepancy — Step 8 always runs
`gh pr create` regardless of remote presence — is expected to surface, gets fixed generalizably,
then the whole flow is re-verified fresh end-to-end.

**Tech Stack:** `skills/itsg-33-remediate/SKILL.md` and `skills/itsg-33-assess/SKILL.md` are
prompt-driven Claude Code skills (Markdown instructions for an LLM agent), not executable code —
there is no compiler, type checker, or unit test framework for them. The one piece of real code
this plan adds is `test/fixtures/sample-app/check-rbac.sh` (POSIX shell, no dependencies) plus
its `Makefile` wrapper.

## Global Constraints

- Verification uses **local tracker mode only** — the scratch copy is `git init`'d with no
  remote, so no real GitHub issues or PRs are created. The ticket's literal "`Closes #<n>`"
  wording is replaced by local mode's actual `Resolves local gap: security/gaps/AC-6.md` line.
- The AC-6 gap is produced by dispatching **only the AC-family** subagent contract from
  `itsg-33-assess/SKILL.md` Step 4 — not all 9 families. This deviates from `itsg-33-assess`'s
  own Step 5.2 "every control in `controls.md` appears in the merged state" completeness check;
  that check is intentionally skipped in Task 3 below since this is a scoped verification run of
  `itsg-33-remediate`, not a second full run of `itsg-33-assess` (already covered by #12/#15).
- `test/fixtures/sample-app/Makefile` and `check-rbac.sh` are a **permanent** addition to the
  checked-in fixture (unlike the scratch `security/` state) — write the check generically (any
  `cluster-admin` `ClusterRoleBinding`), never fixture-specific.
- The AC-6 fix content (remove vs. scope the binding) is decided by the dispatched
  `itsg-33-remediate` agent's own Step 5 reasoning — do not pre-author it in this plan.
- `test/fixtures/sample-app/` itself must never gain a checked-in `security/` folder. All
  runtime state (gap files, evidence cards, `assessment-state.yaml`, git branches) lives only in
  the `/tmp` scratch copies created by this plan's tasks.
- Every verification claim is confirmed by directly reading the resulting files (evidence card,
  gap file, `assessment-state.yaml`, `git log`/`git branch`) — never by trusting a dispatched
  agent's self-report alone.
- Any discrepancy found is classified per the spec: (a) genuine `itsg-33-remediate` gap → fix
  generalizably in `SKILL.md`; (b) artifact of this plan's own scratch harness/dispatch prompt →
  fix the harness, not `SKILL.md`.

---

### Task 1: Add a minimal test to the fixture (`check-rbac.sh` + `Makefile`)

**Files:**
- Create: `test/fixtures/sample-app/check-rbac.sh`
- Create: `test/fixtures/sample-app/Makefile`

**Interfaces:**
- Produces: `check-rbac.sh [path-to-rbac-yaml]` (defaults to `k8s/rbac.yaml` relative to the
  current directory) — exits 1 if a `ClusterRoleBinding` with `roleRef.name: cluster-admin` is
  found, exits 0 otherwise. Consumed by `make test` (no args, so it uses the default path) and,
  later, by `itsg-33-remediate`'s Step 4 test-runner auto-detection (`Makefile` with a `test`
  target).

- [ ] **Step 1: Create temp test fixtures for the checker**

```bash
mkdir -p /tmp/check-rbac-test
cp /home/bernard/github/itsg-33-skill/test/fixtures/sample-app/k8s/rbac.yaml /tmp/check-rbac-test/fail-case.yaml
```

Write `/tmp/check-rbac-test/pass-case.yaml` (same file with the `ClusterRoleBinding` document
removed):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sample-app
  namespace: sample-app
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000002"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: audit-reader
  namespace: sample-app
rules:
  - apiGroups: [""]
    resources: ["pods", "events"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: audit-reader-binding
  namespace: sample-app
subjects:
  - kind: ServiceAccount
    name: audit-service
    namespace: monitoring
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: audit-reader
```

- [ ] **Step 2: Run the checker against fail-case.yaml to confirm it doesn't exist yet**

```bash
/home/bernard/github/itsg-33-skill/test/fixtures/sample-app/check-rbac.sh /tmp/check-rbac-test/fail-case.yaml
```
Expected: `No such file or directory` (the script hasn't been created yet).

- [ ] **Step 3: Implement check-rbac.sh**

Create `test/fixtures/sample-app/check-rbac.sh`:

```bash
#!/bin/bash
# check-rbac.sh [path-to-rbac-yaml]
#
# Fails (exit 1) if the given RBAC manifest contains a ClusterRoleBinding
# whose roleRef.name is the built-in cluster-admin role. Passes (exit 0)
# otherwise. Defaults to k8s/rbac.yaml relative to the current directory.
set -euo pipefail

RBAC_FILE="${1:-k8s/rbac.yaml}"

if [ ! -f "$RBAC_FILE" ]; then
  echo "check-rbac: $RBAC_FILE not found" >&2
  exit 1
fi

if awk '
  /^kind: *ClusterRoleBinding/ { in_crb = 1; next }
  /^---/ { in_crb = 0; next }
  in_crb && /^ *name: *cluster-admin *$/ { found = 1 }
  END { exit(found ? 0 : 1) }
' "$RBAC_FILE"; then
  echo "check-rbac: FAIL - ClusterRoleBinding to cluster-admin found in $RBAC_FILE" >&2
  exit 1
fi

echo "check-rbac: PASS - no ClusterRoleBinding to cluster-admin in $RBAC_FILE"
exit 0
```

```bash
chmod +x /home/bernard/github/itsg-33-skill/test/fixtures/sample-app/check-rbac.sh
```

- [ ] **Step 4: Run against fail-case.yaml to confirm it correctly fails**

```bash
/home/bernard/github/itsg-33-skill/test/fixtures/sample-app/check-rbac.sh /tmp/check-rbac-test/fail-case.yaml; echo "exit: $?"
```
Expected: prints `check-rbac: FAIL - ClusterRoleBinding to cluster-admin found in
/tmp/check-rbac-test/fail-case.yaml` and `exit: 1`.

- [ ] **Step 5: Run against pass-case.yaml to confirm it correctly passes**

```bash
/home/bernard/github/itsg-33-skill/test/fixtures/sample-app/check-rbac.sh /tmp/check-rbac-test/pass-case.yaml; echo "exit: $?"
```
Expected: prints `check-rbac: PASS - no ClusterRoleBinding to cluster-admin in
/tmp/check-rbac-test/pass-case.yaml` and `exit: 0`.

- [ ] **Step 6: Run against the real (unpatched) fixture using the default path**

```bash
cd /home/bernard/github/itsg-33-skill/test/fixtures/sample-app && ./check-rbac.sh; echo "exit: $?"
```
Expected: `check-rbac: FAIL - ClusterRoleBinding to cluster-admin found in k8s/rbac.yaml` and
`exit: 1` — confirms the default-path wiring, and confirms the real fixture is still in its
known deliberate-Fail state.

- [ ] **Step 7: Create the Makefile**

Create `test/fixtures/sample-app/Makefile`:

```makefile
.PHONY: test
test:
	./check-rbac.sh
```

- [ ] **Step 8: Run `make test` to confirm the Makefile wiring**

```bash
cd /home/bernard/github/itsg-33-skill/test/fixtures/sample-app && make test; echo "exit: $?"
```
Expected: same output as Step 6, `exit: 1`.

- [ ] **Step 9: Clean up the temp test fixtures**

```bash
rm -rf /tmp/check-rbac-test
```

- [ ] **Step 10: Commit**

```bash
cd /home/bernard/github/itsg-33-skill
git add test/fixtures/sample-app/check-rbac.sh test/fixtures/sample-app/Makefile
git commit -m "$(cat <<'EOF'
Add check-rbac.sh + Makefile test to sample-app fixture

The fixture had no test runner at all, so itsg-33-remediate's Step 4
test-baseline detection had nothing to find. Adds a minimal, generic
(not fixture-specific) check: fails if any ClusterRoleBinding grants
the built-in cluster-admin role, which is exactly the fixture's
deliberate AC-6 anti-pattern and a real regression check beyond this
one fixture.

Part of #14.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Set up a git-backed scratch copy of the fixture

**Files:** None in this repo. Creates `/tmp/itsg33-verify-remediate` (git repository, no
remote).

**Interfaces:**
- Produces: a scratch git repo at `/tmp/itsg33-verify-remediate` with one commit, no remote,
  containing Task 1's `Makefile`/`check-rbac.sh` — consumed by Task 3's assess dispatch and
  Task 4's remediate dispatch.

- [ ] **Step 1: Create the scratch copy**

```bash
rm -rf /tmp/itsg33-verify-remediate
cp -r /home/bernard/github/itsg-33-skill/test/fixtures/sample-app /tmp/itsg33-verify-remediate
ls /tmp/itsg33-verify-remediate/security 2>&1
```
Expected: `ls: cannot access '/tmp/itsg33-verify-remediate/security': No such file or directory`
(confirms a clean starting state).

- [ ] **Step 2: git init and baseline commit**

```bash
cd /tmp/itsg33-verify-remediate
git init -q
git add -A
git commit -q -m "Baseline: sample-app fixture with check-rbac.sh test"
git log --oneline
```
Expected: one commit, message `Baseline: sample-app fixture with check-rbac.sh test`.

- [ ] **Step 3: Confirm no remote (tracker mode will auto-detect local)**

```bash
cd /tmp/itsg33-verify-remediate && git remote -v
```
Expected: empty output (no remotes configured).

---

### Task 3: Produce a real AC-6 gap via a targeted AC-family assess dispatch

**Files:** None in this repo. Writes into `/tmp/itsg33-verify-remediate/security/`.

**Interfaces:**
- Consumes: `skills/itsg-33-assess/SKILL.md` (Step 4's AC-family subagent contract only),
  `skills/itsg-33-assess/controls.md` (AC family: AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8,
  AC-11, AC-12, AC-17, AC-19), `skills/itsg-33-assess/evidence-card.md`,
  `skills/itsg-33-assess/scripts/write-fragment.py`, `skills/itsg-33-assess/scripts/merge-state.py`.
- Produces: `/tmp/itsg33-verify-remediate/security/itsg33.yaml`,
  `security/assessment-state.yaml`, `security/evidence/AC-*.md` (11 files),
  `security/gaps/AC-6.md` — consumed by Task 4's remediate dispatch.

- [ ] **Step 1: Dispatch the targeted AC-family assess agent**

Use the Agent tool (general-purpose subagent) with this prompt:

```
Follow skills/itsg-33-assess/SKILL.md (absolute path:
/home/bernard/github/itsg-33-skill/skills/itsg-33-assess/SKILL.md) against the repo at
/tmp/itsg33-verify-remediate, with ONE deliberate scope reduction: only assess the AC
control family (AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-11, AC-12, AC-17, AC-19 — read
their entries from /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/controls.md).
Do NOT assess any other family. This is intentional: this is a scoped verification run for
issue #14 (itsg-33-remediate), not a second full itsg-33-assess run.

1. Run the Init branch: system_name "sample-app", system_boundary "single-service GC PBMM
   sample workload", profile "PBMM". Detect tracker mode per Step 1's rule (GitHub remote
   present -> github, absent -> local) - /tmp/itsg33-verify-remediate has no remote, so this
   must come out "local". Write security/itsg33.yaml and create security/evidence/ and
   security/gaps/.
2. Run Assess Steps 1-3 (read config, fingerprint tech stack, load controls.md).
3. Run Step 4's AC-family subagent contract (4a-4e) yourself, directly, for only the 11 AC
   controls listed above - do not dispatch a further sub-agent, since you're already scoped
   to one family. Use evidence-card.md's template for each evidence card.
4. Write the AC family's fragment: security/.assessment-fragments/AC.input.json, then run
   `python3 /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/scripts/write-fragment.py
   AC security/.assessment-fragments/AC.input.json security/.assessment-fragments/AC.json`
   (working directory /tmp/itsg33-verify-remediate).
5. Run merge: `python3
   /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/scripts/merge-state.py
   security/.assessment-fragments security/assessment-state.yaml
   security/assessment-state.yaml PBMM` (working directory /tmp/itsg33-verify-remediate).
   NOTE: skip Step 5.2's "every control in controls.md appears in the merged state" check -
   only 11 of 60 controls exist by design in this scoped run.
6. Delete security/.assessment-fragments/.
7. Run Step 6 (create gap issues) for whichever AC controls came back Fail, in local mode
   (write security/gaps/<control-id>.md).

Report back: the finding for every one of the 11 AC controls, and the exact list of files
you created under security/.
```

- [ ] **Step 2: Verify the reported findings**

Confirm the agent's report shows: AC-2 Pass, AC-3 Pass, AC-4 Pass, AC-5 Pass, AC-6 Fail, AC-7 Not
Assessable, AC-8 Not Assessable, AC-11 Not Assessable, AC-12 Not Assessable, AC-17 Not Assessable,
AC-19 Not Assessable — matching `test/fixtures/sample-app/expected-findings.yaml`. If any AC
control's finding doesn't match, stop and classify per the Global Constraints discrepancy
discipline before continuing (this would indicate the AC-family rubric regressed since issue
#15's Task 6 fixes — a genuine `controls.md`/`SKILL.md` gap, not something to paper over here).

- [ ] **Step 3: Independently verify the output files (don't trust the report alone)**

```bash
test -f /tmp/itsg33-verify-remediate/security/itsg33.yaml && echo "itsg33.yaml OK"
test -f /tmp/itsg33-verify-remediate/security/assessment-state.yaml && echo "assessment-state.yaml OK"
ls /tmp/itsg33-verify-remediate/security/evidence/ | wc -l
ls /tmp/itsg33-verify-remediate/security/gaps/
test -d /tmp/itsg33-verify-remediate/security/.assessment-fragments && echo "FAIL: fragments dir should not survive" || echo "fragments dir cleaned up OK"
grep '"tracker"' /tmp/itsg33-verify-remediate/security/itsg33.yaml
```
Expected: `itsg33.yaml OK`, `assessment-state.yaml OK`, `11` (one evidence card per AC control),
`AC-6.md` listed in `security/gaps/` (and no other file), `fragments dir cleaned up OK`, and the
tracker line shows `local`.

- [ ] **Step 4: Read the AC-6 gap file and evidence card directly**

```bash
cat /tmp/itsg33-verify-remediate/security/gaps/AC-6.md
cat /tmp/itsg33-verify-remediate/security/evidence/AC-6.md
```
Confirm: the gap file references control AC-6, finding Fail, and the evidence card's
`**Severity:**` field reads `P1` (per `controls.md`'s AC-6 entry) and `**Finding:**` reads `Fail`.

---

### Task 4: Dispatch itsg-33-remediate through Steps 1–7, observe Step 8

**Files:** None in this repo. Modifies `/tmp/itsg33-verify-remediate` (new git branch,
commit).

**Interfaces:**
- Consumes: `skills/itsg-33-remediate/SKILL.md` (current, pre-fix), the
  `/tmp/itsg33-verify-remediate` state left by Task 3.
- Produces: a pass/fail verdict for Steps 1–7, plus a captured failure mode for Step 8, used by
  Task 5 to confirm the fix and Task 6 to re-verify.

- [ ] **Step 1: Dispatch the remediate agent**

Use the Agent tool (general-purpose subagent) with this prompt:

```
Follow skills/itsg-33-remediate/SKILL.md (absolute path:
/home/bernard/github/itsg-33-skill/skills/itsg-33-remediate/SKILL.md) against the repo at
/tmp/itsg33-verify-remediate.

Work through Steps 1-10 exactly as written, with these two rules for this dry run:
- At Step 5 ("Propose fix"), after you present your proposed fix, approve it yourself
  (there is no live user to ask) and proceed to Step 6. State the proposal clearly in your
  report before approving it.
- At Step 10 ("Continue or stop"), choose "stop" (there is only one gap).

Report back, in order:
1. What Step 1 loaded (the gap record: control ID, severity, finding, confidence, evidence
   card path, source reference).
2. The Step 2 sort result (trivial with one gap, but confirm it ran).
3. What Step 3 presented to the "user".
4. What Step 4 detected as the test runner, the exact command it ran, and the baseline
   result (expect: Makefile found, `make test` run, exit 1 / FAIL, since the cluster-admin
   binding is still present at this point).
5. Your exact Step 5 fix proposal (which file(s), what change).
6. The exact branch name Step 6 created and the commit(s) on it.
7. The exact command and result Step 7 ran to verify green.
8. What happened at Step 8 - run it exactly as SKILL.md currently specifies (do not skip it
   or work around it even if it looks like it will fail) and report the exact command run and
   its exact output/error.
9. Whether you reached Step 9 or Step 10, and what happened there.

Do not stop early because Step 8 looks like it might fail against a repo with no GitHub
remote - run it anyway and report exactly what happens. That failure, if it happens, is
expected and will be fixed in a later step of this plan, not by you working around it now.
```

- [ ] **Step 2: Verify Steps 1–3 against the Task 3 gap record**

Confirm the report's Step 1 record matches Task 3's AC-6 gap file/evidence card (control AC-6,
severity P1, finding Fail).

- [ ] **Step 3: Independently verify the Step 4 baseline**

```bash
cd /tmp/itsg33-verify-remediate && git log --oneline --all
git branch -a
```
At this point (before Step 6 branch creation), confirm only the one baseline commit from Task 2
exists. Then independently re-run the baseline command yourself to confirm the reported result:

```bash
cd /tmp/itsg33-verify-remediate && make test; echo "exit: $?"
```
Expected: `check-rbac: FAIL - ...` and `exit: 1`, matching what the agent reported as its Step 4
baseline.

- [ ] **Step 4: Independently verify the Step 6 branch and Step 7 green result**

```bash
cd /tmp/itsg33-verify-remediate
git branch -a
git log --oneline itsg33/fix/AC-6
git diff main itsg33/fix/AC-6 -- k8s/rbac.yaml
git checkout -q itsg33/fix/AC-6 && make test; echo "exit: $?"
git checkout -q main
```
Expected: branch `itsg33/fix/AC-6` exists with at least one commit beyond baseline, the diff
shows the `cluster-admin` `ClusterRoleBinding` removed or replaced with a narrower binding, and
`make test` on that branch exits 0.

- [ ] **Step 5: Confirm the Step 8 failure is exactly the expected discrepancy**

Read the agent's reported Step 8 command/output. Confirm it attempted `gh pr create --draft
...` and failed because `/tmp/itsg33-verify-remediate` has no GitHub remote (e.g. `gh: unknown
repository` / "no git remote found" / equivalent `gh` error). If Step 8 failed for a *different*
reason, or if it silently skipped instead of erroring, stop and re-classify before continuing to
Task 5 — Task 5's fix is specifically for the no-remote case.

---

### Task 5: Fix itsg-33-remediate/SKILL.md Step 8 to gate on remote presence

**Files:**
- Modify: `skills/itsg-33-remediate/SKILL.md` (Step 8 body, Step 8's completion criterion, Step
  9's opening sentence and completion criterion)

**Interfaces:** N/A (prose-only change to an existing skill step; no new interfaces).

- [ ] **Step 1: Replace Step 8's body**

Find the `### Step 8 — Open draft PR` section (from its heading through its `Completion:` line,
currently reading in part `gh pr create --draft --title "<title>" --body "<body>"` unconditionally)
and replace it with:

```markdown
### Step 8 — Open draft PR

First, check whether a usable GitHub remote exists (the same check `itsg-33-assess` Step 1
uses to detect tracker mode):

```bash
git remote -v
```

**If a remote exists:** proceed as below.

Title: `fix(<control-id>): <control name> — <one-line summary>`.

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
- Local mode: `Resolves local gap: security/gaps/<control-id>.md` — since
  there's no merge-triggered auto-close in local mode, follow it with a line
  asking the user to delete that file once this PR merges.

```bash
gh pr create --draft --title "<title>" --body "<body>"
```

Completion: a draft PR exists with the correct title format and every body
field populated (no field left as a placeholder).

**If no remote exists:** stop here — do not run `gh pr create` (there is nothing to open a PR
against). Tell the user: the fix is committed on branch `itsg33/fix/<control-id>` with tests
green, but no draft PR was opened because this repo has no GitHub remote; push a remote and
re-invoke this step (or open the PR manually) once one exists. Completion (no-remote case): the
branch and its green commit exist; the user has been told why no PR was opened.
```

- [ ] **Step 2: Update Step 9's opening sentence and completion criterion**

Find the `### Step 9 — Update POA&M` section's opening line (`Edit
security/evidence/<control-id>.md's header block to add or update a **Remediation Ticket:** <PR
URL> line...`) and its `Completion:` line. Replace the whole section with:

```markdown
### Step 9 — Update POA&M

**If Step 8 opened a PR:** edit `security/evidence/<control-id>.md`'s header block to add or
update a `**Remediation Ticket:** <PR URL>` line, alongside its existing `Severity` and
`Finding` fields. The evidence card is the artifact meant to persist into the SAR package, so
it — not the gap issue or gap file, which close or get deleted — is where this link needs to
survive.

For local tracker mode only, also add or update the same
`**Remediation Ticket:** <PR URL>` line in the still-open gap file, so the
team can see the link while that file still exists, ahead of its manual
deletion after merge.

Known limitation: the evidence card is a generated file — a future
`itsg-33-assess` run that re-assesses this control (a cache miss) rewrites it
from `evidence-card.md`'s template, which has no `Remediation Ticket` field,
silently dropping this line. Treat it as best-effort, not durable; the
authoritative record is the merged PR itself (and, in GitHub mode, the closed
gap issue's linked PR). `assessment-report.md`'s POA&M table won't show this
link either, since it's generated from `assessment-state.yaml`, which also has
no such field — closing that gap belongs to a future `itsg-33-assess` change,
not this skill.

**If Step 8 stopped because there was no remote:** skip this step entirely — there is no PR URL
to record yet. Proceed directly to Step 10.

Completion: either the evidence card's (and, in local mode, the gap file's) `Remediation
Ticket` field is set to the PR URL, or Step 8 had no remote and this step was skipped.
```

- [ ] **Step 3: Consistency check (grep)**

```bash
grep -n "^### Step" skills/itsg-33-remediate/SKILL.md
```
Expected: 10 lines, `Step 1` through `Step 10`, in order, no gaps or duplicates (heading text
changes are fine; only the count/order/numbering matters here).

```bash
grep -n "git remote -v" skills/itsg-33-remediate/SKILL.md
```
Expected: exactly one occurrence, inside the new Step 8.

```bash
grep -n "no remote" skills/itsg-33-remediate/SKILL.md
```
Expected: at least 2 occurrences (Step 8's no-remote branch, Step 9's no-remote branch).

- [ ] **Step 4: Full read-through**

Read the entire `skills/itsg-33-remediate/SKILL.md` file top to bottom. Confirm:
- Step 8 and Step 9 read coherently as a pair (Step 9 correctly branches on what Step 8 did).
- No other step assumes a remote exists (Steps 1–7 and Step 10 are all remote-independent —
  confirm this is still true after the edit, i.e. nothing else needs a matching change).

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-remediate/SKILL.md
git commit -m "$(cat <<'EOF'
Gate itsg-33-remediate Step 8 on GitHub remote presence

Step 8 previously ran `gh pr create` unconditionally regardless of
tracker mode, but there's nothing to open a PR against when the repo
has no GitHub remote (the same condition that makes tracker mode
`local` in the first place). Verified live against a scratch copy of
the sample-app fixture (issue #14): Step 8 failed on `gh pr create`
with no remote configured. Step 8 now checks for a remote first; with
none, it stops after the green Step 7 baseline, leaves the fix
committed on its branch, and tells the user to push and open the PR
manually once a remote exists. Step 9 gets a matching no-remote branch
since there's no PR URL yet to record in the POA&M.

Part of #14.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Fresh end-to-end re-verification with the fixed SKILL.md

**Files:** None modified in this repo. Uses a **fresh** scratch copy (Task 4's
`/tmp/itsg33-verify-remediate` already has an `itsg33/fix/AC-6` branch and Step-8 failure state
from before the fix — start clean rather than reusing it).

**Interfaces:**
- Consumes: the fixed `skills/itsg-33-remediate/SKILL.md` from Task 5, `skills/itsg-33-assess/SKILL.md`.

- [ ] **Step 1: Create a fresh scratch copy**

```bash
rm -rf /tmp/itsg33-verify-remediate2
cp -r /home/bernard/github/itsg-33-skill/test/fixtures/sample-app /tmp/itsg33-verify-remediate2
ls /tmp/itsg33-verify-remediate2/security 2>&1
cd /tmp/itsg33-verify-remediate2
git init -q
git add -A
git commit -q -m "Baseline: sample-app fixture with check-rbac.sh test"
git log --oneline
git remote -v
```
Expected: `ls` reports `No such file or directory` (clean start), one commit, no remotes.

- [ ] **Step 2: Re-establish the AC-6 gap via a targeted AC-family assess dispatch**

Use the Agent tool (general-purpose subagent) with this prompt:

```
Follow skills/itsg-33-assess/SKILL.md (absolute path:
/home/bernard/github/itsg-33-skill/skills/itsg-33-assess/SKILL.md) against the repo at
/tmp/itsg33-verify-remediate2, with ONE deliberate scope reduction: only assess the AC
control family (AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-11, AC-12, AC-17, AC-19 — read
their entries from /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/controls.md).
Do NOT assess any other family. This is intentional: this is a scoped verification run for
issue #14 (itsg-33-remediate), not a second full itsg-33-assess run.

1. Run the Init branch: system_name "sample-app", system_boundary "single-service GC PBMM
   sample workload", profile "PBMM". Detect tracker mode per Step 1's rule (GitHub remote
   present -> github, absent -> local) - /tmp/itsg33-verify-remediate2 has no remote, so this
   must come out "local". Write security/itsg33.yaml and create security/evidence/ and
   security/gaps/.
2. Run Assess Steps 1-3 (read config, fingerprint tech stack, load controls.md).
3. Run Step 4's AC-family subagent contract (4a-4e) yourself, directly, for only the 11 AC
   controls listed above - do not dispatch a further sub-agent, since you're already scoped
   to one family. Use evidence-card.md's template for each evidence card.
4. Write the AC family's fragment: security/.assessment-fragments/AC.input.json, then run
   `python3 /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/scripts/write-fragment.py
   AC security/.assessment-fragments/AC.input.json security/.assessment-fragments/AC.json`
   (working directory /tmp/itsg33-verify-remediate2).
5. Run merge: `python3
   /home/bernard/github/itsg-33-skill/skills/itsg-33-assess/scripts/merge-state.py
   security/.assessment-fragments security/assessment-state.yaml
   security/assessment-state.yaml PBMM` (working directory /tmp/itsg33-verify-remediate2).
   NOTE: skip Step 5.2's "every control in controls.md appears in the merged state" check -
   only 11 of 60 controls exist by design in this scoped run.
6. Delete security/.assessment-fragments/.
7. Run Step 6 (create gap issues) for whichever AC controls came back Fail, in local mode
   (write security/gaps/<control-id>.md).

Report back: the finding for every one of the 11 AC controls, and the exact list of files
you created under security/.
```

Verify exactly as in Task 3 Steps 2–4: findings match `expected-findings.yaml` (AC-2/3/4/5
Pass, AC-6 Fail, AC-7/8/11/12/17/19 Not Assessable); `security/itsg33.yaml`,
`security/assessment-state.yaml`, 11 evidence cards, and `security/gaps/AC-6.md` (only) all
exist under `/tmp/itsg33-verify-remediate2`; the fragments directory was cleaned up; tracker
mode is `local`; and the gap file/evidence card read back with control AC-6, severity P1,
finding Fail.

- [ ] **Step 3: Dispatch the remediate agent against the fresh copy with the fixed SKILL.md**

Use the Agent tool (general-purpose subagent) with this prompt:

```
Follow skills/itsg-33-remediate/SKILL.md (absolute path:
/home/bernard/github/itsg-33-skill/skills/itsg-33-remediate/SKILL.md) against the repo at
/tmp/itsg33-verify-remediate2.

Work through Steps 1-10 exactly as written, with these two rules for this dry run:
- At Step 5 ("Propose fix"), after you present your proposed fix, approve it yourself
  (there is no live user to ask) and proceed to Step 6. State the proposal clearly in your
  report before approving it.
- At Step 10 ("Continue or stop"), choose "stop" (there is only one gap).

Report back, in order:
1. What Step 1 loaded (the gap record: control ID, severity, finding, confidence, evidence
   card path, source reference).
2. The Step 2 sort result (trivial with one gap, but confirm it ran).
3. What Step 3 presented to the "user".
4. What Step 4 detected as the test runner, the exact command it ran, and the baseline
   result (expect: Makefile found, `make test` run, exit 1 / FAIL, since the cluster-admin
   binding is still present at this point).
5. Your exact Step 5 fix proposal (which file(s), what change).
6. The exact branch name Step 6 created and the commit(s) on it.
7. The exact command and result Step 7 ran to verify green.
8. What happened at Step 8. Step 8 should now check for a GitHub remote first and, finding
   none (this repo has no remote), stop cleanly after Step 7's green result instead of
   running `gh pr create` — report exactly what it did and what it told the user.
9. What happened at Step 9 (expect: skipped, since Step 8 had no remote and there's no PR
   URL to record) and Step 10.

Do not stop early for any reason short of an actual step failure.
```

- [ ] **Step 4: Verify all of ticket #14's acceptance criteria directly**

```bash
cd /tmp/itsg33-verify-remediate2
git branch -a
git log --oneline itsg33/fix/AC-6
git checkout -q itsg33/fix/AC-6 && make test; echo "exit: $?"
git checkout -q main
cat security/evidence/AC-6.md | grep -i "Remediation Ticket" || echo "no Remediation Ticket field set (expected - no remote)"
cat security/gaps/AC-6.md | grep -i "Remediation Ticket" || echo "no Remediation Ticket field set in gap file (expected - no remote)"
```

Confirm, matching ticket #14's acceptance criteria:
- [ ] AC-6 presented as the first (only) gap, P1 severity (from Task 6 Step 3's report, cross-
      checked against `security/evidence/AC-6.md`).
- [ ] Test baseline captured (`Makefile` detected, `make test` run, baseline FAIL) before any
      fix was applied.
- [ ] Branch `itsg33/fix/AC-6` created from the correct base commit.
- [ ] The fix removes or scopes the `cluster-admin` binding (`git diff main itsg33/fix/AC-6 --
      k8s/rbac.yaml`).
- [ ] `make test` passes on the branch.
- [ ] Step 8 correctly stops with no remote (no `gh pr create` error this time — a clean,
      reported "no remote, PR deferred" outcome instead) — this replaces the ticket's literal
      "draft PR opened" criterion per the tracker-mode decision recorded in the spec.
- [ ] `Remediation Ticket` is **not** set in either `security/evidence/AC-6.md` or
      `security/gaps/AC-6.md` (Step 9 correctly skipped since there's no PR URL yet) — this
      replaces the ticket's literal "`remediation_ticket` populated" criterion for the same
      reason.
- [ ] No discrepancies found in this re-run beyond the already-fixed Step 8/9 gate (if any new
      discrepancy appears, classify it per the Global Constraints discipline and decide with the
      user whether it needs its own fix before closing out).

- [ ] **Step 5: Clean up scratch copies**

```bash
rm -rf /tmp/itsg33-verify-remediate /tmp/itsg33-verify-remediate2
```

---

### Task 7: Final report

**Files:** None (no repo changes expected — Tasks 1 and 5 already committed everything this
plan produces). If Task 6 surfaced and required fixing a further discrepancy, that fix should
already have been committed following Task 5's pattern before reaching this task.

- [ ] **Step 1: Confirm nothing is left uncommitted**

```bash
cd /home/bernard/github/itsg-33-skill && git status
```
Expected: clean (no uncommitted changes) — Task 1's fixture test and Task 5's Step 8/9 fix are
the only repo changes this plan makes, both already committed.

- [ ] **Step 2: Summarize the verification result for the user**

Report: which of ticket #14's 11 verification steps and 8 acceptance criteria passed, the one
discrepancy found and fixed (Step 8's unconditional `gh pr create`), and that issue #14 is ready
to be closed (leave the actual GitHub issue-closing/push to the user, per standing project
practice of not pushing/closing without explicit go-ahead).
