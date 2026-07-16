# Generalize controls.md File patterns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `itsg-33-assess` from reporting false Not Assessable findings on repos that
use IaC tools, CI/CD systems, or languages outside the hardcoded set the current File
patterns anticipate.

**Architecture:** Add a small set of named, reusable glob families (`{IaC}`, `{CI/CD}`,
`{App source}`) to `controls.md`, swap every control's matching bare pattern for the family
name, and give `SKILL.md` Step 4b a one-time fallback check (against Step 2's now-broadened
tech-stack survey) before it concludes Not Assessable on a zero-glob-match.

**Tech Stack:** Markdown (`controls.md`, `SKILL.md` — LLM-read instructions, no executable
code); `sed`/`grep` for scripted, verifiable bulk text substitution.

## Global Constraints

- Design source of truth: `docs/superpowers/specs/2026-07-16-controls-pattern-generalization-design.md`.
- Every `File patterns` line must remain a single line ending in two trailing spaces
  (existing Markdown hard-line-break convention in `controls.md` — verify this isn't broken
  by any edit).
- No control's **Pass signals**, **Fail signals**, or **Not Assessable** text changes in this
  plan — only **File patterns** lines and the two `SKILL.md` steps named above.
- `test/fixtures/sample-app/` (Terraform + K8s + GitHub Actions + Python) must produce
  unchanged findings after this change — the family expansion is additive only.

---

### Task 1: Add Common Pattern Families section to controls.md

**Files:**
- Modify: `skills/itsg-33-assess/controls.md:9-17` (insert new section between "How to read
  an entry" and the AC family header)

**Interfaces:**
- Produces: three named glob families — `{IaC}`, `{CI/CD}`, `{App source}` — referenced by
  every subsequent task in this plan.

- [ ] **Step 1: Read the current section boundary**

Run: `sed -n '9,19p' skills/itsg-33-assess/controls.md`

Expected output (current content, confirming insertion point):
```
## How to read an entry

- **File patterns** — glob patterns the skill uses for targeted reads. Read files matching these patterns first.
- **Pass signals** — concrete artifacts or config patterns that indicate the control is satisfied.
- **Fail signals** — concrete artifacts or config patterns that indicate a gap.
- **Not Assessable** — when to report Not Assessable instead of Pass or Fail.

---

## AC — Access Control
```

- [ ] **Step 2: Insert the new section and the cross-reference line**

Use the Edit tool on `skills/itsg-33-assess/controls.md`:

old_string:
```
- **File patterns** — glob patterns the skill uses for targeted reads. Read files matching these patterns first.
- **Pass signals** — concrete artifacts or config patterns that indicate the control is satisfied.
- **Fail signals** — concrete artifacts or config patterns that indicate a gap.
- **Not Assessable** — when to report Not Assessable instead of Pass or Fail.

---

## AC — Access Control
```

new_string:
```
- **File patterns** — glob patterns the skill uses for targeted reads. Read files matching these patterns first. A `{Name}` token in a File patterns line expands to the corresponding glob set defined in **Common Pattern Families** below.
- **Pass signals** — concrete artifacts or config patterns that indicate the control is satisfied.
- **Fail signals** — concrete artifacts or config patterns that indicate a gap.
- **Not Assessable** — when to report Not Assessable instead of Pass or Fail.

---

## Common Pattern Families

Reusable glob sets referenced by name from individual controls' File patterns lines, so
adding support for a new tool or language means editing one definition here rather than
sweeping every control that uses it.

- **`{IaC}`** — `**/*.tf`, `**/*.bicep`, `**/*.template.yaml`, `**/*.template.json`, `**/cloudformation/**`, `**/Pulumi.*.yaml`, `**/*.pulumi.*`, `**/playbook*.yml`, `**/*.ansible.yml`
- **`{CI/CD}`** — `.github/workflows/*.yaml`, `.gitlab-ci.yml`, `azure-pipelines*.yml`, `.circleci/config.yml`, `Jenkinsfile`
- **`{App source}`** — `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/*.cs`, `**/*.rs`, `**/*.rb`, `**/*.php`, `**/*.kt`, `**/*.swift`, `**/*.cpp`, `**/*.scala`

A control's File patterns line may combine a family token with its own control-specific
literal patterns (e.g. `{IaC}`, `**/rbac*.yaml`) — the literal patterns stay inline since
they aren't shared across controls.

---

## AC — Access Control
```

- [ ] **Step 3: Verify the insertion**

Run: `grep -n "^## Common Pattern Families$" skills/itsg-33-assess/controls.md`
Expected: one match, e.g. `19:## Common Pattern Families`

Run: `grep -c '^\- \*\*`{IaC}`\*\*' skills/itsg-33-assess/controls.md`
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-assess/controls.md
git commit -m "Add Common Pattern Families section to controls.md"
```

---

### Task 2: Replace bare `**/*.tf` with `{IaC}` across all controls

**Files:**
- Modify: `skills/itsg-33-assess/controls.md` (46 occurrences, all in **File patterns**
  lines below the AC family header)

**Interfaces:**
- Consumes: `{IaC}` family defined in Task 1.

- [ ] **Step 1: Confirm baseline count**

Run: `grep -o '`\*\*/\*\.tf`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `46`

(This must be exactly 46 before proceeding — if it isn't, Task 1's insertion touched an
existing pattern line unexpectedly; stop and investigate before running the substitution.)

- [ ] **Step 2: Run the substitution**

```bash
sed -i 's/`\*\*\/\*\.tf`/`{IaC}`/g' skills/itsg-33-assess/controls.md
```

This targets only the exact backtick-wrapped token `` `**/*.tf` ``, not the other
control-specific `.tf` patterns (e.g. `` `**/bastion*.tf` ``, `` `**/backup*.tf` ``), which
don't match this literal string and are left untouched.

- [ ] **Step 3: Verify the substitution**

Run: `grep -o '`\*\*/\*\.tf`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `0`

Run: `grep -o '`{IaC}`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `46`

Run: `grep -c '`\*\*/bastion\*\.tf`' skills/itsg-33-assess/controls.md`
Expected: `1` (confirms control-specific `.tf` patterns were not touched)

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-assess/controls.md
git commit -m "Replace bare **/*.tf with {IaC} family reference in controls.md"
```

---

### Task 3: Replace bare `.github/workflows/*.yaml` with `{CI/CD}` across all controls

**Files:**
- Modify: `skills/itsg-33-assess/controls.md` (15 occurrences)

**Interfaces:**
- Consumes: `{CI/CD}` family defined in Task 1.

- [ ] **Step 1: Confirm baseline count**

Run: `grep -o '`\.github/workflows/\*\.yaml`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `15`

- [ ] **Step 2: Run the substitution**

```bash
sed -i 's/`\.github\/workflows\/\*\.yaml`/`{CI\/CD}`/g' skills/itsg-33-assess/controls.md
```

- [ ] **Step 3: Verify the substitution**

Run: `grep -o '`\.github/workflows/\*\.yaml`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `0`

Run: `grep -o '`{CI/CD}`' skills/itsg-33-assess/controls.md | wc -l`
Expected: `15`

Run: `grep -c '`\.github/CODEOWNERS`' skills/itsg-33-assess/controls.md`
Expected: `3` (confirms the other `.github/...` literal patterns, e.g. CODEOWNERS and
branch_protection, were not touched)

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-assess/controls.md
git commit -m "Replace bare .github/workflows/*.yaml with {CI/CD} family reference in controls.md"
```

---

### Task 4: Replace SI-10 and SI-11 language enumerations with `{App source}`

**Files:**
- Modify: `skills/itsg-33-assess/controls.md` (SI-10 and SI-11 File patterns lines only)

**Interfaces:**
- Consumes: `{App source}` family defined in Task 1.

- [ ] **Step 1: Locate the two lines**

Run: `grep -n "^\*\*File patterns:\*\* \`\*\*/\*\.go\`" skills/itsg-33-assess/controls.md`

Expected: two matches — one for SI-10, one for SI-11, e.g.:
```
487:**File patterns:** `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/*.cs`, `**/handler*.go`, `**/controller*.go`, `**/routes*.py`
496:**File patterns:** `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/error*.go`, `**/middleware*.go`
```
(Line numbers will differ from the pre-edit file since Tasks 1-3 shifted line numbers —
match on content, not the exact numbers shown here.)

- [ ] **Step 2: Edit the SI-10 line**

Use the Edit tool on `skills/itsg-33-assess/controls.md`:

old_string:
```
**File patterns:** `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/*.cs`, `**/handler*.go`, `**/controller*.go`, `**/routes*.py`  
```

new_string:
```
**File patterns:** `{App source}`, `**/handler*.go`, `**/controller*.go`, `**/routes*.py`  
```

- [ ] **Step 3: Edit the SI-11 line**

Use the Edit tool on `skills/itsg-33-assess/controls.md`:

old_string:
```
**File patterns:** `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/error*.go`, `**/middleware*.go`  
```

new_string:
```
**File patterns:** `{App source}`, `**/error*.go`, `**/middleware*.go`  
```

- [ ] **Step 4: Verify**

Run: `grep -c "App source" skills/itsg-33-assess/controls.md`
Expected: `3` (the 1 definition line from Task 1, plus these 2 new usage lines)

Run: `grep -c '`\*\*/\*\.go`' skills/itsg-33-assess/controls.md`
Expected: `0` (no bare `**/*.go` tokens remain anywhere, including inside the family
definition — it's written as `{App source}` there too, not spelled out)

- [ ] **Step 5: Commit**

```bash
git add skills/itsg-33-assess/controls.md
git commit -m "Replace SI-10/SI-11 language enumeration with {App source} family reference"
```

---

### Task 5: Broaden SKILL.md Step 2's tech-stack survey

**Files:**
- Modify: `skills/itsg-33-assess/SKILL.md` (Step 2 — "Fingerprint tech stack")

**Interfaces:**
- Produces: the expanded signal table and catch-all extension list that Task 6's Step 4b
  fallback reads.

- [ ] **Step 1: Read the current step**

Run: `sed -n '/### Step 2/,/^### Step 3/p' skills/itsg-33-assess/SKILL.md`

Expected (current content):
```
### Step 2 — Fingerprint tech stack

Detect which file patterns are present in the repo:

| Signal | Pattern |
|--------|---------|
| Terraform | `**/*.tf` |
| Kubernetes manifests | `**/*.yaml`, `**/*.yml` (k8s heuristic: contains `apiVersion:` and `kind:`) |
| Helm values | `**/values*.yaml` |
| Dockerfile | `**/Dockerfile*` |
| GitHub Actions | `.github/workflows/*.yaml` |
| Go module | `go.mod` |
| Node | `package.json` |
| Python | `requirements*.txt`, `pyproject.toml` |

Completion: list of detected signal families recorded (e.g., `[terraform, kubernetes, github-actions]`).

### Step 3 — Load control catalogue
```

- [ ] **Step 2: Replace the step**

Use the Edit tool on `skills/itsg-33-assess/SKILL.md`:

old_string:
```
### Step 2 — Fingerprint tech stack

Detect which file patterns are present in the repo:

| Signal | Pattern |
|--------|---------|
| Terraform | `**/*.tf` |
| Kubernetes manifests | `**/*.yaml`, `**/*.yml` (k8s heuristic: contains `apiVersion:` and `kind:`) |
| Helm values | `**/values*.yaml` |
| Dockerfile | `**/Dockerfile*` |
| GitHub Actions | `.github/workflows/*.yaml` |
| Go module | `go.mod` |
| Node | `package.json` |
| Python | `requirements*.txt`, `pyproject.toml` |

Completion: list of detected signal families recorded (e.g., `[terraform, kubernetes, github-actions]`).
```

new_string:
```
### Step 2 — Fingerprint tech stack

Detect which file patterns are present in the repo:

| Signal | Pattern |
|--------|---------|
| Terraform | `**/*.tf` |
| Pulumi | `Pulumi.*.yaml`, `**/*.pulumi.*` |
| CloudFormation / SAM | `**/*.template.yaml`, `**/*.template.json`, `**/cloudformation/**` |
| Bicep / ARM | `**/*.bicep` |
| Ansible | `**/playbook*.yml`, `**/*.ansible.yml` |
| Kubernetes manifests | `**/*.yaml`, `**/*.yml` (k8s heuristic: contains `apiVersion:` and `kind:`) |
| Helm values | `**/values*.yaml` |
| Dockerfile | `**/Dockerfile*` |
| GitHub Actions | `.github/workflows/*.yaml` |
| GitLab CI | `.gitlab-ci.yml` |
| Azure Pipelines | `azure-pipelines*.yml` |
| CircleCI | `.circleci/config.yml` |
| Jenkins | `Jenkinsfile` |
| Go module | `go.mod` |
| Node | `package.json` |
| Python | `requirements*.txt`, `pyproject.toml` |
| Rust | `Cargo.toml` |
| Ruby | `Gemfile` |
| PHP | `composer.json` |
| Kotlin | `**/*.kt` |
| Swift | `**/*.swift`, `Package.swift` |
| C++ | `**/*.cpp`, `**/CMakeLists.txt` |
| Scala | `**/*.scala`, `build.sbt` |

Also record any other distinct top-level file extensions present in the repo that aren't
covered above (a broad `find . -type f | sed 's/.*\.//' | sort -u`-style listing is
sufficient). This catches a stack the table above doesn't anticipate at all, so Step 4b's
fallback has something to check against for a control whose glob patterns come up empty.

Completion: list of detected signal families recorded (e.g., `[terraform, kubernetes,
github-actions]`), plus the catch-all extension list.
```

- [ ] **Step 3: Verify**

Run: `grep -c "Pulumi" skills/itsg-33-assess/SKILL.md`
Expected: `1`

Run: `grep -c "catch-all extension list" skills/itsg-33-assess/SKILL.md`
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-assess/SKILL.md
git commit -m "Broaden SKILL.md Step 2 tech-stack survey beyond Terraform/K8s/GitHub Actions"
```

---

### Task 6: Add the Step 4b fallback before Not Assessable

**Files:**
- Modify: `skills/itsg-33-assess/SKILL.md` (subagent contract, step "4b. Read relevant
  files")

**Interfaces:**
- Consumes: the Step 2 survey (Task 5) and the `{Name}` family-expansion note in
  `controls.md` (Task 1).

- [ ] **Step 1: Read the current step**

Run: `grep -n -A2 "\*\*4b\. Read relevant files\*\*" skills/itsg-33-assess/SKILL.md`

Expected (current content):
```
**4b. Read relevant files**
Glob the control's **File patterns** against the repo. If no files match any pattern →
finding is **Not Assessable**; record `reason: no matching files`; skip to 4d.
```

- [ ] **Step 2: Replace the step**

Use the Edit tool on `skills/itsg-33-assess/SKILL.md`:

old_string:
```
**4b. Read relevant files**
Glob the control's **File patterns** against the repo. If no files match any pattern →
finding is **Not Assessable**; record `reason: no matching files`; skip to 4d.
```

new_string:
```
**4b. Read relevant files**
Glob the control's **File patterns** against the repo, expanding any `{Name}` token per
`controls.md`'s Common Pattern Families section. If at least one file matches, read the
matched files and proceed to 4c.

If no files match any pattern, check the Step 2 survey for a tool or language present in
the repo that this control's patterns didn't anticipate (e.g., the survey shows Pulumi,
Bicep, CloudFormation, Ansible, GitLab CI, Azure Pipelines, or a source language outside
`{App source}`'s list). If such a signal exists, glob for that tool's characteristic files
(per the Step 2 table) and read them, then proceed to 4c.

Only if this fallback also turns up nothing → finding is **Not Assessable**; record
`reason: no matching files (including tech-stack fallback)`; skip to 4d.
```

- [ ] **Step 3: Verify**

Run: `grep -c "tech-stack fallback" skills/itsg-33-assess/SKILL.md`
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add skills/itsg-33-assess/SKILL.md
git commit -m "Add Step 4b tech-stack fallback before Not Assessable in itsg-33-assess"
```

---

### Task 7: Regression check against the sample-app fixture

**Files:**
- None modified — read-only verification task.

**Interfaces:**
- Consumes: everything from Tasks 1-6.

- [ ] **Step 1: Confirm the fixture's expected findings are unaffected on paper**

Run: `cat test/fixtures/sample-app/expected-findings.yaml`

Read through it alongside the edited `controls.md`. For every control the fixture has an
expected finding for, confirm that control's (possibly family-expanded) File patterns line
still matches the same fixture files it matched before this change — the family expansion
only *adds* patterns, it never removes one, so every previously-matching literal pattern
(e.g. `**/rbac*.yaml`, `**/values*.yaml`) is still present verbatim on each control's line.

- [ ] **Step 2: Invoke itsg-33-assess against a scratch copy of the fixture**

Per this repo's established fixture-verification constraint (see
`docs/superpowers/specs/2026-07-15-remediate-fixture-verification-design.md`'s Background
section), `test/fixtures/sample-app/` must not gain a checked-in `security/` folder — all
runtime output belongs in a disposable scratch copy, not the fixture itself.

```bash
rm -rf /tmp/itsg33-pattern-check
cp -r test/fixtures/sample-app /tmp/itsg33-pattern-check
cd /tmp/itsg33-pattern-check && git init -q && git add -A && git commit -q -m "scratch baseline"
```

(No remote is added, so `itsg-33-assess`'s tracker-mode detection resolves to `local` —
matching the same no-side-effects posture the remediate fixture-verification spec used.)

Run the `itsg-33-assess` skill (via the Skill tool) with `/tmp/itsg33-pattern-check` as the
target repo — the full 9-family dispatch, since this change touches patterns across nearly
every family, not just one.

Expected: findings for every control listed in `test/fixtures/sample-app/README.md`'s
"Deliberate findings" and "Deliberate passes" tables match exactly (same Pass/Fail verdict,
same reasoning basis) — no control that previously found evidence now reports Not
Assessable, and no previously-Not-Assessable control's verdict changed either. The fixture
is a pure Terraform/K8s/GitHub-Actions/Python repo, so Task 6's fallback path should never
trigger for it — every match should come from Task 1-4's family expansion covering the same
ground as the original literal patterns.

Clean up afterward: `rm -rf /tmp/itsg33-pattern-check`.

- [ ] **Step 3: Record the result**

If all findings match: no code change needed, this task is done.

If any finding regressed: identify which family substitution (Task 2, 3, or 4) dropped a
pattern the fixture relied on, fix that family's definition in `controls.md` (Task 1's
section), and re-run this task's Step 2 before proceeding.

---

## Self-Review Notes

- **Spec coverage:** Part 1 (`controls.md` families) → Tasks 1-4. Part 2 (`SKILL.md`
  fallback) → Tasks 5-6. Verification plan's fixture dry-run → Task 7. All three spec
  sections have a task.
- **No placeholders:** every substitution is an exact `sed`/Edit old-string/new-string pair
  with a verifying `grep` command and expected count — nothing says "similarly update the
  rest" without showing the rest.
- **Consistency:** `{IaC}`, `{CI/CD}`, `{App source}` names match exactly between Task 1's
  definitions, Tasks 2-4's substitutions, and Task 6's Step 4b prose referencing `{App
  source}` by name.
