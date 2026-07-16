# Parallel Family-Fan-Out Assessment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `itsg-33-assess/SKILL.md`'s sequential per-control assessment loop (Step 4) with
a per-control-family subagent fan-out, so both real end-user assessments and fixture-verification
iterations run 9 families in parallel instead of walking all 60 controls one at a time.

**Architecture:** Step 4 becomes an orchestration step that dispatches one subagent per control
family (AC, AU, IA, SC, CM, SI, SA, CP, RA); each subagent runs the existing 4a-4d reasoning loop
plus evidence-card writing for only its own family and writes a scratch fragment file. A new
Step 5 merges all 9 fragments into the single `assessment-state.yaml`, runs the plausibility
check over the merged result, and deletes the fragments. Steps 6-8 (renumbered from the old 7-9)
run once, unchanged in content, after the merge.

**Tech Stack:** N/A — `itsg-33-assess` is a prompt-driven Claude Code skill (`SKILL.md` is
instructions for an LLM agent, not executable code). There is no compiler, type checker, or unit
test framework for this repo.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-15-parallel-family-assessment-design.md` — follow it
  exactly; in particular, always-parallel (no opt-in flag), fragment-file-then-merge (never
  direct shared writes), retry-once-then-hard-abort on subagent failure.
- The Step 4c Pass/Fail/Not-Assessable reasoning rubric (control interpretation rules) is
  **unchanged** — only its execution context moves from "main sequential loop" to "per-family
  subagent." Copy it verbatim; do not edit its wording as part of this plan.
- No automated test suite exists for this repo. "Tests" here are (a) grep-based consistency
  checks on the edited Markdown, run after each task, and (b) the three-pass fixture
  verification against `test/fixtures/sample-app/` (mirroring issue #12's acceptance gate),
  run once at the end as the "full test suite."
- Per standing project guidance: if fixture verification surfaces a discrepancy, fix it as a
  generalizable rubric/instruction change in `SKILL.md`/`controls.md` — never hardcode an
  answer specific to `test/fixtures/sample-app`.
- Verification passes must run against a **temporary copy** of `test/fixtures/sample-app/`
  (e.g. under `/tmp`), never in-place — the fixture directory has no `security/` folder
  checked in and should stay that way.

---

## File Structure

- **Modify:** `skills/itsg-33-assess/SKILL.md` — this is the only file this plan changes.
  - Step 4 heading/content: replaced (dispatch + per-family subagent contract)
  - Step 5 heading/content: replaced (merge + plausibility check, moved from old post-Step-4 position)
  - Old Step 6 heading: removed (its content folds into the new Step 4's subagent contract)
  - Old Steps 7, 8, 9: renumbered to 6, 7, 8; content unchanged
- **No new files** are created in this repo. `security/.assessment-fragments/`,
  `security/assessment-state.yaml`, etc. are runtime artifacts written by an agent *consuming*
  the skill (e.g. in a target repo or the test fixture during verification), not part of this
  repo's source.

---

### Task 1: Rewrite Step 4 — dispatch + per-family subagent contract

**Files:**
- Modify: `skills/itsg-33-assess/SKILL.md:67-178` (current "Step 4 — Assess each control"
  section, from the `### Step 4` heading through the end of 4d, not including the post-loop
  plausibility check block)

**Interfaces:**
- Produces: the fragment file schema `security/.assessment-fragments/<family>.yaml` that
  Task 2's merge step (Step 5) consumes — top-level keys `family` (string) and `controls`
  (map of control-id → `{finding, confidence, risk_summary, implementation_approach,
  evidence_artefacts, client_responsibility, files_read}`), identical field names to today's
  `assessment-state.yaml` control entries.

- [ ] **Step 1: Replace the Step 4 section**

Open `skills/itsg-33-assess/SKILL.md` and replace everything from the `### Step 4 — Assess each
control` heading through the end of step `4d`'s completion criterion (i.e. up to, but not
including, the `*(End of per-control loop...)*` separator and the Plausibility check block that
follows it) with:

```markdown
### Step 4 — Dispatch family subagents

Partition `controls.md` by control family prefix: **AC, AU, IA, SC, CM, SI, SA, CP, RA**. In a
single message, dispatch one subagent per family (Task/Agent tool, parallel calls) — every
family gets a subagent every run, even if none of its controls changed since the last run.

Each subagent's dispatch prompt must include:
- The active `profile`, `system_name`, `system_boundary`, and tracker mode (from Step 1)
- The detected signal list from Step 2
- A pointer to `controls.md`, with an instruction to process only entries whose control ID
  starts with its assigned family prefix
- A pointer to `evidence-card.md` (the template to use when writing evidence cards)
- The subagent contract below (steps 4a-4d and 6)

**Subagent contract (per family)**

For each control in the assigned family, in order:

**4a. Cache check**
Read `security/assessment-state.yaml`. For each file listed under this control's
`files_read`, hash the current content and compare to the stored hash. If all hashes
match → mark this control `cached`, carry the prior finding forward, and do not rewrite
its evidence card. Skip to next control.

**4b. Read relevant files**
Glob the control's **File patterns** against the repo. If no files match any pattern →
finding is **Not Assessable**; record `reason: no matching files`; skip to 4d.

**4c. Reason**
Read the matched files. Apply the control's **Pass signals** and **Fail signals** from
`controls.md`, using these rules to weigh them:

- **Signal lists are alternatives, not a checklist.** Pass signals and Fail signals are each
  an *OR* list of examples, not a set of requirements that must all be satisfied. One clear,
  concrete positive signal is enough for Pass; you do not need every listed pass signal to be
  present. Likewise, one clear negative signal is enough for Fail.
- **Fail requires a concrete artifact, not just an unverified gap.** Only report Fail when
  you observe a specific anti-pattern in a matched file (e.g., a `cluster-admin` binding, a
  hardcoded credential, unsanitized query concatenation), or a narrow case where this control
  exists specifically to assess whether a foundational capability is present at all and that
  capability is entirely absent (see the cascading rule below for how to tell foundational
  controls apart from the dependent controls that build on them — this is a narrow exception,
  not a general license to fail any missing nice-to-have). Do not report Fail merely because a
  *particular* pass signal can't be verified from repo contents alone (e.g., GitHub
  branch-protection settings, an IdP's MFA policy, image-signing enforcement) when nothing in
  the repo actively contradicts it — that is a **Not Assessable**, not a Fail.
- **Pass equally requires a concrete positive artifact, not just the absence of a Fail
  pattern.** The inverse of the rule above holds just as strongly: don't award Pass merely
  because you didn't find the specific anti-pattern from the Fail-signal list. If the
  capability this control assesses was never actually implemented anywhere in the repo — no
  bastion/VPN config, no monitoring/alerting config, and so on — that is **Not Assessable**,
  not Pass, even though nothing looks actively broken. Reserve Pass for when you can point to a
  specific artifact that positively implements what the control asks for.
- **A satisfied core Pass signal outweighs an unmet optional item on the Fail-signal list.**
  Fail-signal lists often mix two different things: "the practice doesn't exist at all" and
  "an additional layer or enhancement of an already-working practice is missing" (e.g., a
  scanner that runs on every PR and blocks merge, but doesn't *also* run on a schedule or
  *also* cover IaC specifically). When a clear, concrete Pass signal is satisfied by the core
  mechanism, don't let an unmet optional completeness item flip the finding to Fail — only do
  that when the Fail-list item describes an active defect in the *same* mechanism you were
  about to credit (e.g., the scanner exists but doesn't block merge, or runs with
  `continue-on-error: true`). Ask whether the missing item is a defect in what's there, or an
  unimplemented extra layer on top of something that already works.
- **An entirely unattempted specialized practice is Not Assessable, not Fail.** Some controls
  assess a specialized or supplementary practice (e.g., software license scanning, image
  signing, pre-commit secret scanning) that plenty of otherwise well-secured systems simply
  haven't adopted, as distinct from a baseline capability every system in scope is expected to
  have. If the repo shows no attempt at the practice at all — not even a partial or
  misconfigured one — prefer Not Assessable over Fail. Reserve Fail for this class of control
  when there's a broken or half-implemented attempt (e.g., an admission controller present but
  not enforcing any policy, or a license-scan step that exists but is disabled).
- **A broad pattern match (e.g. `**/*.tf`) is not itself a positive or negative signal.**
  Many controls list catch-all patterns like `**/*.tf` so the relevant resource can be found
  if present. Matching a file under that pattern does not, on its own, satisfy Step 4b's
  "files matched" gate for *this control's subject matter* — read the file's content and ask
  whether it actually relates to what this control assesses. A Terraform file that has nothing
  to do with logging does not make AU-4 Fail; it means the log-storage resource AU-4 cares
  about was never introduced (see the cascading rule below).
- **Cascading Not Assessable within a family.** Within a control family, some controls assess
  whether a foundational capability exists *at all*, while others assess a property of a
  pipeline that presupposes that capability exists. In the AU family specifically: AU-2
  (auditable events), AU-3 (audit record content), and AU-12 (audit generation) together
  assess whether any audit logging exists at all — if no audit logging pipeline is configured
  anywhere in the repo (no K8s audit policy, no cloud audit log resource, no structured
  app-level security event logging), mark all three **Fail**, since "there is no audit trail at
  all" is itself the finding for each of them. AU-4 (storage capacity), AU-5 (failure
  alerting), AU-8 (time stamps), AU-9 (protection of audit info), and AU-11 (retention) assess
  *properties* of that pipeline — if the foundational pipeline is entirely absent, mark these
  **Not Assessable**, since there is nothing to evaluate the property of. Do not fail a
  dependent control for a property of something that doesn't exist, and do not excuse a
  foundational control to Not Assessable just because no dedicated logging file type is
  present. The same foundational-vs-dependent shape can recur in other families — ask whether
  the control is asking "does this capability exist" (foundational) or "how good/complete is
  the existing thing" (dependent) before assuming absence of one implies the same verdict for
  the other.
- **Don't re-litigate one control's finding inside another — and expect legitimate
  disagreement between controls that share evidence.** If an issue is already the precise
  subject of a more specific control (e.g., overly-broad IAM/RBAC privilege is AC-6's
  concern), don't also fail a different control (e.g., AC-2, which is about whether accounts
  are explicitly defined and tokens aren't auto-mounted) for the same underlying fact unless
  that control's own signals are about something distinct. At the same time, two controls
  reading the *same* files can correctly land on different findings, because they assess
  different properties of the same evidence: a namespace-scoped Role with an explicit,
  non-wildcard verb list can make an access-enforcement-mechanism control Pass (the mechanism
  exists and is granular) even while a separate, overly-broad cluster-wide binding elsewhere in
  the same manifest set makes a least-privilege control Fail (a grant elsewhere violates
  minimality) — mechanism existence/granularity and privilege minimality are distinct
  questions, and are not required to agree. Read what each control is actually named and scoped
  to assess, not just whether a fail-signal keyword string appears in a matched file.
- **Don't confuse artifacts with similar names.** A resource that shares a keyword with a
  control's subject (e.g., a *backup* retention period vs. an *audit log* retention period) is
  only evidence for that control if it is actually the same kind of artifact — check what the
  resource actually stores before citing it.

Derive:
- `finding`: Pass / Fail / Not Assessable
- `confidence`: plain-English note explaining what was found or not found
- `risk_summary`: one-to-two sentence attacker-perspective statement (from controls.md risk context)
- `implementation_approach`: narrative of how the system implements (or fails to implement) the control, citing specific files and config constructs
- `evidence_artefacts`: bulleted list of relative file paths with a note on what each demonstrates
- `client_responsibility`: what application teams must do to maintain their side of this control
- `files_read`: map of `<relative path>` → SHA-256 of file content (used for cache check in 4a and stored in the fragment file)

**4d. Record finding**
Completion criterion: every control in the assigned family has a finding (Pass / Fail /
Not Assessable / cached) and a confidence note.

**6. Write evidence card**
For each control with a finding (including cached, per 4a's no-rewrite rule), write/update
`security/evidence/<control-id>.md` using the template at [`evidence-card.md`](evidence-card.md)
(load via this context pointer). Populate all fields from the finding recorded in 4c/4d.
Completion: one `.md` file per control in the assigned family exists in `security/evidence/`.

*(End of per-control loop.)*

Write the family's results to a scratch fragment file
`security/.assessment-fragments/<family>.yaml`:
```yaml
family: <family>
controls:
  <control-id>:
    finding: <Pass | Fail | Not Assessable>
    confidence: <string>
    risk_summary: <string>
    implementation_approach: <string>
    evidence_artefacts: [<relative path>, ...]
    client_responsibility: <string>
    files_read:
      <relative path>: <sha256>
```
Completion: every control in the assigned family appears exactly once in the fragment file.

**Failure handling:** If a subagent errors, returns malformed output, or produces a fragment
missing/duplicating a control, the orchestrator retries that one family's subagent once. If the
retry also fails, abort the entire run: report which family failed and why, leave
`security/assessment-state.yaml` and `security/evidence/` untouched, and leave
`security/.assessment-fragments/` in place for debugging. Do not proceed to Step 5.
```

- [ ] **Step 2: Consistency check (grep)**

Run:
```bash
grep -n "^### Step 4\|^### Step 5\|4a\. Cache check\|Plausibility check" skills/itsg-33-assess/SKILL.md
```
Expected: exactly one `### Step 4 — Dispatch family subagents` heading, exactly one
`4a. Cache check` occurrence (the old Step 4's 4a text should be gone, replaced by this one),
and the `Plausibility check` heading should NOT appear yet inside Step 4 (it still lives after
Step 4's old location until Task 2 moves it — confirm it appears exactly once, right after this
new Step 4 block, unchanged for now).

- [ ] **Step 3: Commit**

```bash
git add skills/itsg-33-assess/SKILL.md
git commit -m "$(cat <<'EOF'
Replace itsg-33-assess Step 4 with per-family subagent dispatch

Step 4 now partitions controls.md by family (AC, AU, IA, SC, CM, SI,
SA, CP, RA) and dispatches one subagent per family in parallel. Each
subagent runs the existing 4a-4d reasoning loop (rubric unchanged) plus
evidence-card writing for only its own family, and writes a scratch
fragment file instead of touching assessment-state.yaml directly.

Part of #15.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Rewrite Step 5 (merge), remove old Step 6, renumber 7-9 to 6-8

**Files:**
- Modify: `skills/itsg-33-assess/SKILL.md` (the `*(End of per-control loop...)*` separator and
  Plausibility check block that now trails Task 1's new Step 4; the old
  `### Step 5 — Update assessment state` section; the old `### Step 6 — Write evidence cards`
  section; the headings of old Steps 7, 8, 9)

**Interfaces:**
- Consumes: the fragment file schema from Task 1 (`security/.assessment-fragments/<family>.yaml`,
  keys `family` and `controls`)
- Produces: the merged `security/assessment-state.yaml` shape consumed by Step 4a's cache check
  and by Step 6 (gap issues) / Step 7 (MD report) / Step 8 (HTML report) — unchanged shape:
  `{last_run: <ISO-8601>, controls: {<control-id>: {finding, confidence, files_read}}}`

- [ ] **Step 1: Remove the now-stale post-Step-4 separator and Plausibility check block**

Delete this block (it trails the old Step 4, right before `### Step 5 — Update assessment state`):

```markdown
---
*(End of per-control loop. The following check runs once after all controls are assessed.)*

**Plausibility check**
If `profile: PBMM` and **all** of the following returned Not Assessable:
- Every SC (System and Communications Protection) control
- Every IA (Identification and Authentication) control

→ append a synthetic finding `PLAUSIBILITY-WARNING`:
  - Finding: Not Assessable
  - Confidence: "PBMM declared but no encryption, auth, or network config was found. Verify the repo contains the relevant IaC or manifests, or that the system boundary is correctly scoped."

```

(Its content is folded into the new Step 5 below — do not lose the wording, just relocate it.)

- [ ] **Step 2: Replace old Step 5 ("Update assessment state") with the new merge step**

Replace:
```markdown
### Step 5 — Update assessment state

Write/update `security/assessment-state.yaml`. Structure:
```yaml
last_run: <ISO-8601 timestamp>
controls:
  <control-id>:
    finding: <Pass | Fail | Not Assessable>
    confidence: <string>
    files_read:
      <relative path>: <sha256>
```
Completion: file written; every assessed (non-cached) control has an updated entry.
```

with:
```markdown
### Step 5 — Merge state

Once all 9 fragments exist in `security/.assessment-fragments/`:

1. Read all fragments. Confirm every control in `controls.md` appears in exactly one
   fragment. A control missing from all fragments, or present in more than one, is treated
   as a subagent failure per Step 4's failure handling: retry that family once, then abort.
2. Merge the fragments' `controls:` maps into a single map and write/update
   `security/assessment-state.yaml`:
   ```yaml
   last_run: <ISO-8601 timestamp>
   controls:
     <control-id>:
       finding: <Pass | Fail | Not Assessable>
       confidence: <string>
       files_read:
         <relative path>: <sha256>
   ```
3. **Plausibility check** — if `profile: PBMM` and **all** of the following returned Not
   Assessable in the merged result:
   - Every SC (System and Communications Protection) control
   - Every IA (Identification and Authentication) control

   → append a synthetic finding `PLAUSIBILITY-WARNING`:
     - Finding: Not Assessable
     - Confidence: "PBMM declared but no encryption, auth, or network config was found.
       Verify the repo contains the relevant IaC or manifests, or that the system boundary
       is correctly scoped."
4. Delete `security/.assessment-fragments/`.

Completion: `security/assessment-state.yaml` contains an entry for every control in
`controls.md`; the fragment directory no longer exists.
```

- [ ] **Step 3: Remove old Step 6 heading (content already folded into Step 4 by Task 1)**

Delete:
```markdown
### Step 6 — Write evidence cards

For each control with a finding (including cached), write/update
`security/evidence/<control-id>.md` using the template at [`evidence-card.md`](evidence-card.md)
(load via this context pointer). Populate all fields from the finding recorded in Step 4.
Completion: one `.md` file per assessed control exists in `security/evidence/`.
```
(This text is already present, reworded, inside Task 1's new Step 4 — do not duplicate it here.)

- [ ] **Step 4: Renumber old Steps 7, 8, 9 to 6, 7, 8**

Change these three heading lines (content below each heading is unchanged):
- `### Step 7 — Create gap issues` → `### Step 6 — Create gap issues`
- `### Step 8 — Regenerate assessment report (Markdown)` → `### Step 7 — Regenerate assessment report (Markdown)`
- `### Step 9 — Regenerate assessment report (HTML)` → `### Step 8 — Regenerate assessment report (HTML)`

- [ ] **Step 5: Consistency check (grep)**

Run:
```bash
grep -n "^### Step" skills/itsg-33-assess/SKILL.md
```
Expected output: exactly 8 lines, `Step 1` through `Step 8` in order, no gaps, no duplicates,
and no `Step 9` remaining.

```bash
grep -n "assessment-fragments" skills/itsg-33-assess/SKILL.md
```
Expected: at least two occurrences (one in Step 4's fragment-write instruction, one in Step 5's
merge/delete instructions).

- [ ] **Step 6: Full read-through**

Read the entire `skills/itsg-33-assess/SKILL.md` file top to bottom. Confirm:
- No leftover reference to "the main loop" or "sequential" assessment
- No dangling reference to a step number that no longer exists (e.g. old "skip to 4d" references still say 4d, which still exists — confirm no reference says "Step 6" meaning evidence cards, since Step 6 is now gap issues)
- The Init branch (Steps 1-6 there, unrelated numbering) is untouched

- [ ] **Step 7: Commit**

```bash
git add skills/itsg-33-assess/SKILL.md
git commit -m "$(cat <<'EOF'
Add merge step, renumber report/gap steps in itsg-33-assess

Step 5 now merges the 9 per-family fragment files from Step 4 into
assessment-state.yaml and runs the plausibility check over the merged
result (moved from its old post-loop position, since it needs all
SC/IA findings together). Old Step 6 (evidence cards) is removed as a
standalone step since it now runs inside each family subagent. Old
Steps 7-9 (gap issues, Markdown report, HTML report) renumber to 6-8
with unchanged content.

Part of #15.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Verification Pass 1 — fresh init+assess against the fixture

**Files:**
- None modified. Reads `skills/itsg-33-assess/SKILL.md`, `skills/itsg-33-assess/controls.md`,
  `skills/itsg-33-assess/evidence-card.md`, and a temp copy of
  `test/fixtures/sample-app/`. Compares against
  `test/fixtures/sample-app/expected-findings.yaml`.

**Interfaces:**
- Consumes: the final `SKILL.md` from Tasks 1-2.
- Produces: a pass/fail verdict plus a list of any (control, expected, actual) mismatches, used
  by Task 6 if fixes are needed.

- [ ] **Step 1: Create a scratch copy of the fixture**

```bash
rm -rf /tmp/itsg33-verify-pass1
cp -r /home/bernard/github/itsg-33-skill/test/fixtures/sample-app /tmp/itsg33-verify-pass1
ls /tmp/itsg33-verify-pass1/security 2>&1
```
Expected: `ls: cannot access ... No such file or directory` (confirms a clean starting state,
no prior `security/` folder).

- [ ] **Step 2: Dispatch an orchestrator agent to run the Assess branch (Init + Assess) against the scratch copy**

Use the Agent tool (general-purpose subagent, since it needs to itself dispatch 9 family
subagents via its own Agent tool access) with a prompt instructing it to:
- Follow `skills/itsg-33-assess/SKILL.md` (absolute path) against the repo at
  `/tmp/itsg33-verify-pass1`
- Use system name `sample-app`, system boundary `single-service GC PBMM sample workload`,
  profile `PBMM`, tracker mode `local` (no GitHub remote assumptions)
- Execute the Init branch (since no `security/itsg33.yaml` exists yet) then continue into the
  Assess branch, dispatching one subagent per control family per the new Step 4, merging per
  the new Step 5, then completing Steps 6-8
- Report back: which families it dispatched, whether any failed/retried, and the final
  `security/assessment-state.yaml` contents

- [ ] **Step 3: Verify output structure**

```bash
test -f /tmp/itsg33-verify-pass1/security/itsg33.yaml && echo "itsg33.yaml OK"
test -f /tmp/itsg33-verify-pass1/security/assessment-state.yaml && echo "assessment-state.yaml OK"
test -d /tmp/itsg33-verify-pass1/security/evidence && echo "evidence dir OK"
test -f /tmp/itsg33-verify-pass1/security/assessment-report.md && echo "MD report OK"
test -f /tmp/itsg33-verify-pass1/security/assessment-report.html && echo "HTML report OK"
test -d /tmp/itsg33-verify-pass1/security/.assessment-fragments && echo "FAIL: fragments dir should not survive" || echo "fragments dir cleaned up OK"
```
Expected: first five checks print "OK"; the fragments-dir check prints "fragments dir cleaned up OK".

- [ ] **Step 4: Verify findings match expected-findings.yaml**

Read `/tmp/itsg33-verify-pass1/security/assessment-state.yaml` and
`/home/bernard/github/itsg-33-skill/test/fixtures/sample-app/expected-findings.yaml`
side by side. For every control listed in `expected-findings.yaml`, confirm the `finding`
value matches. List any mismatches (control ID, expected, actual) for Task 6.

- [ ] **Step 5: Verify gap issues for expected Fail controls**

```bash
ls /tmp/itsg33-verify-pass1/security/gaps/
```
Expected: a file exists for at least AC-6, SC-28, AU-2 (the controls issue #12 named as expected
Fails), matching the finding table from Step 4 above.

No commit for this task (no repo files change) — proceed directly to Task 4. If mismatches were
found, note them and continue verification passes 2 and 3 before fixing anything in Task 6 (so
all discrepancies are known before editing the rubric).

---

### Task 4: Verification Pass 2 — no-op incremental re-run

**Files:** None modified in this repo. Re-runs against the same `/tmp/itsg33-verify-pass1` copy
from Task 3 (unchanged fixture files).

**Interfaces:**
- Consumes: the `/tmp/itsg33-verify-pass1` state left by Task 3.

- [ ] **Step 1: Snapshot evidence card mtimes and state hashes before re-run**

```bash
find /tmp/itsg33-verify-pass1/security/evidence -type f -printf '%T@ %p\n' | sort > /tmp/itsg33-pass2-before-mtimes.txt
sha256sum /tmp/itsg33-verify-pass1/security/assessment-state.yaml > /tmp/itsg33-pass2-before-hash.txt
```

- [ ] **Step 2: Dispatch an orchestrator agent to re-run the Assess branch on the unchanged copy**

Same as Task 3 Step 2, pointed at `/tmp/itsg33-verify-pass1` again (now with `security/itsg33.yaml`
already present, so it goes straight to the Assess branch, not Init).

- [ ] **Step 3: Verify no evidence cards were rewritten**

```bash
find /tmp/itsg33-verify-pass1/security/evidence -type f -printf '%T@ %p\n' | sort > /tmp/itsg33-pass2-after-mtimes.txt
diff /tmp/itsg33-pass2-before-mtimes.txt /tmp/itsg33-pass2-after-mtimes.txt && echo "PASS: no evidence card mtimes changed"
```
Expected: `diff` reports no differences; "PASS" line prints.

- [ ] **Step 4: Verify assessment-state.yaml content is stable (hash of the controls: map, not the whole file, since last_run timestamp legitimately changes)**

Read the new `/tmp/itsg33-verify-pass1/security/assessment-state.yaml`. Confirm every control's
`finding`, `confidence`, and `files_read` hashes are byte-identical to Task 3's version — only
`last_run` should differ.

- [ ] **Step 5: Verify the fragments directory was cleaned up again**

```bash
test -d /tmp/itsg33-verify-pass1/security/.assessment-fragments && echo "FAIL" || echo "PASS: fragments dir absent"
```

No commit for this task.

---

### Task 4.5: Fragment write-enforcement script (write-fragment.py)

**Context (why this task exists):** Verification Pass 2 (Task 4) found that 3 of 9 family
subagents wrote structurally malformed fragment YAML (e.g. unquoted `confidence:` strings
containing colons), and that Task 3's merge step silently degraded instead of treating this as
the "malformed output" case Step 4's failure handling already names — this let corrupted/empty
`files_read` hashes reach `assessment-state.yaml`, causing spurious cache misses in Task 4. The
fragment file is a brand-new artifact introduced by this restructuring (9 independent subagents
each freehand-writing YAML with no quoting guidance), so this is a restructuring-caused bug, not
a pre-existing one. Fix: subagents no longer hand-write fragment YAML at all. They write their
control data as JSON (a format LLMs reliably emit correctly) to a scratch input file via the
Write tool (no shell-escaping risk, since Write takes exact string content), then a small,
dependency-free script validates and canonically re-serializes it. A script failure is
unambiguous and actionable — the subagent fixes its input and retries — rather than a merge-time
guess.

**Files:**
- Create: `skills/itsg-33-assess/scripts/write-fragment.py`
- Create: `skills/itsg-33-assess/scripts/test_write_fragment.py`
- Modify: `skills/itsg-33-assess/SKILL.md` (Step 4's fragment-write instructions and failure
  handling clause; Step 5's fragment-read instructions)

**Interfaces:**
- Produces: `security/.assessment-fragments/<family>.json` (same field names as the current
  fragment schema — `family`, `controls: {<id>: {finding, confidence, risk_summary,
  implementation_approach, evidence_artefacts, client_responsibility, files_read}}` — just JSON
  instead of hand-written YAML), which Step 5's merge step (Task 2) now reads as JSON instead of
  YAML.

- [ ] **Step 1: Write the failing tests**

Create `skills/itsg-33-assess/scripts/test_write_fragment.py`:

```python
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "write-fragment.py"

VALID_CONTROL = {
    "finding": "Fail",
    "confidence": "High: no audit logging configuration found anywhere in the repo.",
    "risk_summary": "An attacker's actions leave no trail.",
    "implementation_approach": "No K8s audit policy, no cloud audit log resource.",
    "evidence_artefacts": ["k8s/deployment.yaml"],
    "client_responsibility": "Configure platform audit logging.",
    "files_read": {
        "k8s/deployment.yaml": "a" * 64,
    },
}


class WriteFragmentTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.input_path = Path(self.tmpdir.name) / "in.json"
        self.output_path = Path(self.tmpdir.name) / "out.json"

    def run_script(self, family, payload):
        self.input_path.write_text(json.dumps(payload))
        return subprocess.run(
            [sys.executable, str(SCRIPT), family, str(self.input_path), str(self.output_path)],
            capture_output=True,
            text=True,
        )

    def test_valid_fragment_writes_canonical_json(self):
        payload = {"family": "AU", "controls": {"AU-2": VALID_CONTROL}}
        result = self.run_script("AU", payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(self.output_path.read_text())
        self.assertEqual(written, payload)

    def test_empty_files_read_is_valid(self):
        control = dict(VALID_CONTROL, files_read={}, finding="Not Assessable")
        payload = {"family": "CM", "controls": {"CM-10": control}}
        result = self.run_script("CM", payload)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_family_mismatch_fails(self):
        payload = {"family": "AU", "controls": {"AU-2": VALID_CONTROL}}
        result = self.run_script("SI", payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("family", result.stderr.lower())
        self.assertFalse(self.output_path.exists())

    def test_missing_required_field_fails(self):
        control = dict(VALID_CONTROL)
        del control["confidence"]
        payload = {"family": "AU", "controls": {"AU-2": control}}
        result = self.run_script("AU", payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("confidence", result.stderr.lower())

    def test_invalid_finding_value_fails(self):
        control = dict(VALID_CONTROL, finding="Maybe")
        payload = {"family": "AU", "controls": {"AU-2": control}}
        result = self.run_script("AU", payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("finding", result.stderr.lower())

    def test_invalid_files_read_hash_format_fails(self):
        control = dict(VALID_CONTROL, files_read={"k8s/deployment.yaml": "not-a-hash"})
        payload = {"family": "AU", "controls": {"AU-2": control}}
        result = self.run_script("AU", payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("files_read", result.stderr.lower())

    def test_malformed_json_input_fails(self):
        self.input_path.write_text("{not valid json")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "AU", str(self.input_path), str(self.output_path)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("json", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_write_fragment.py -v
```
Expected: `FileNotFoundError` or similar — `write-fragment.py` does not exist yet. All 7 tests error/fail.

- [ ] **Step 3: Implement the script**

Create `skills/itsg-33-assess/scripts/write-fragment.py`:

```python
#!/usr/bin/env python3
"""Validate and canonically write an itsg-33-assess fragment file.

Usage: write-fragment.py <family> <input-json-path> <output-json-path>

Reads a family subagent's per-control assessment data as JSON, validates
it against the fragment schema, and writes a canonical JSON fragment.
Exits non-zero with a specific message on any validation failure so the
calling subagent can fix its input and retry, per SKILL.md Step 4's
"malformed output" failure handling.
"""
import json
import re
import sys

VALID_FINDINGS = {"Pass", "Fail", "Not Assessable"}
REQUIRED_CONTROL_FIELDS = [
    "finding",
    "confidence",
    "risk_summary",
    "implementation_approach",
    "evidence_artefacts",
    "client_responsibility",
    "files_read",
]
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def fail(message):
    print(f"write-fragment: {message}", file=sys.stderr)
    sys.exit(1)


def validate(family, data):
    if not isinstance(data, dict):
        fail("top-level JSON must be an object")
    if data.get("family") != family:
        fail(f"family mismatch: expected '{family}', got {data.get('family')!r}")
    controls = data.get("controls")
    if not isinstance(controls, dict) or not controls:
        fail("'controls' must be a non-empty object")

    for control_id, control in controls.items():
        if not isinstance(control, dict):
            fail(f"{control_id}: control entry must be an object")
        for field in REQUIRED_CONTROL_FIELDS:
            if field not in control:
                fail(f"{control_id}: missing required field 'confidence'" if field == "confidence"
                     else f"{control_id}: missing required field '{field}'")

        if control["finding"] not in VALID_FINDINGS:
            fail(f"{control_id}: invalid finding {control['finding']!r}, "
                 f"must be one of {sorted(VALID_FINDINGS)}")

        if not isinstance(control["confidence"], str) or not control["confidence"].strip():
            fail(f"{control_id}: 'confidence' must be a non-empty string")

        if not isinstance(control["evidence_artefacts"], list):
            fail(f"{control_id}: 'evidence_artefacts' must be a list")

        files_read = control["files_read"]
        if not isinstance(files_read, dict):
            fail(f"{control_id}: 'files_read' must be an object")
        for path, digest in files_read.items():
            if not isinstance(digest, str) or not SHA256_RE.match(digest):
                fail(f"{control_id}: files_read[{path!r}] is not a 64-char lowercase "
                     f"SHA-256 hex digest: {digest!r}")


def main():
    if len(sys.argv) != 4:
        fail("usage: write-fragment.py <family> <input-json-path> <output-json-path>")
    family, input_path, output_path = sys.argv[1:4]

    try:
        with open(input_path) as f:
            raw = f.read()
    except OSError as e:
        fail(f"cannot read input file: {e}")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        fail(f"input is not valid json: {e}")

    validate(family, data)

    with open(output_path, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"write-fragment: wrote {len(data['controls'])} controls to {output_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_write_fragment.py -v
```
Expected: all 7 tests pass.

- [ ] **Step 5: Update SKILL.md Step 4's fragment-write instructions**

In `skills/itsg-33-assess/SKILL.md`, find the block starting `Write the family's results to a
scratch fragment file` (in the new Step 4 from Task 1, right after the `*(End of per-control
loop.)*` marker) through the end of its YAML example and completion criterion. Replace it with:

```markdown
Write the family's results as JSON to a scratch input file
`security/.assessment-fragments/<family>.input.json`:
```json
{
  "family": "<family>",
  "controls": {
    "<control-id>": {
      "finding": "<Pass | Fail | Not Assessable>",
      "confidence": "<string>",
      "risk_summary": "<string>",
      "implementation_approach": "<string>",
      "evidence_artefacts": ["<relative path>", "..."],
      "client_responsibility": "<string>",
      "files_read": {"<relative path>": "<sha256>"}
    }
  }
}
```

Then run:
```bash
python3 skills/itsg-33-assess/scripts/write-fragment.py <family> \
  security/.assessment-fragments/<family>.input.json \
  security/.assessment-fragments/<family>.json
```

If this exits non-zero, its stderr names exactly what is wrong (missing field, invalid finding
value, malformed JSON, invalid `files_read` hash). Fix the input file and re-run the script — up
to 2 attempts. If it still fails after 2 attempts, this counts as the "malformed output" case in
the failure handling below.

Completion: every control in the assigned family appears exactly once in
`security/.assessment-fragments/<family>.json`, and the script exited 0.
```

- [ ] **Step 6: Update SKILL.md Step 4's failure handling clause**

Find: `**Failure handling:** If a subagent errors, returns malformed output, or produces a
fragment missing/duplicating a control, the orchestrator retries that one family's subagent
once.`

Replace with: `**Failure handling:** If a subagent errors, exhausts its 2 write-fragment.py
retry attempts without a clean exit, or produces a fragment missing/duplicating a control, the
orchestrator retries that one family's subagent once.` (Keep the rest of the sentence — "If the
retry also fails, abort..." — unchanged.)

- [ ] **Step 7: Update SKILL.md Step 5's merge step to read JSON fragments**

In Step 5 ("Merge state"), change `security/.assessment-fragments/<family>.yaml` to
`security/.assessment-fragments/<family>.json` everywhere it appears, and change "Read all
fragments" to "Read and JSON-parse all fragments" (fragments are now guaranteed valid JSON by
write-fragment.py, so no fallback/recovery logic is needed here — a fragment that fails to parse
at this point is a genuine bug and should hit the same missing-control failure path as any other
malformed fragment).

- [ ] **Step 8: Consistency check (grep)**

```bash
grep -n "assessment-fragments" skills/itsg-33-assess/SKILL.md
```
Expected: every occurrence now ends in `.json` or `.input.json`, none in `.yaml`.

```bash
grep -rn "write-fragment.py" skills/itsg-33-assess/SKILL.md
```
Expected: at least one occurrence (Step 4's fragment-write instructions).

- [ ] **Step 9: Commit**

```bash
git add skills/itsg-33-assess/scripts/write-fragment.py \
        skills/itsg-33-assess/scripts/test_write_fragment.py \
        skills/itsg-33-assess/SKILL.md
git commit -m "$(cat <<'EOF'
Enforce fragment JSON validity via write-fragment.py script

Verification Pass 2 found that hand-written fragment YAML from family
subagents can be malformed (unquoted colon-containing confidence
strings), and that the merge step silently degraded instead of
treating this as a failure — corrupting files_read hashes and causing
spurious cache misses. Family subagents now write their data as JSON
and invoke write-fragment.py, which validates the schema and
canonically re-serializes it; a validation failure is an explicit,
actionable error the subagent can fix and retry, rather than a
merge-time guess.

Part of #15.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Re-run Verification Pass 2 (Task 4) to confirm the fix**

Repeat Task 4's steps against a **fresh** scratch copy (the prior `/tmp/itsg33-verify-pass1` has
already gone through Task 3+4's runs and may carry corrupted state from before this fix):

```bash
rm -rf /tmp/itsg33-verify-pass1
cp -r /home/bernard/github/itsg-33-skill/test/fixtures/sample-app /tmp/itsg33-verify-pass1
```

Dispatch a fresh init+assess (Task 3 Step 2), then immediately a no-op re-run (Task 4 Steps 1-5)
against this new copy. Confirm: no fragment JSON parse/validation failures in either run, no
evidence card mtime changes on the no-op re-run, and no `files_read` hash is empty or malformed
in the resulting `assessment-state.yaml`. This replaces the old `/tmp/itsg33-verify-pass1` state
as the baseline Task 5 continues from.

No further verification passes are re-run in this task — Task 5 (changed-file re-assessment)
still needs to run fresh regardless, and will now exercise the fixed write path.

---

### Task 4.6: Merge-time script enforcement for cached-control fields (merge-state.py)

**Context (why this task exists):** Task 4.5 made fragment *writing* deterministic
(write-fragment.py), and Step 4a's instructions were tightened to require family subagents to
copy a cached control's `finding`/`confidence`/`files_read` verbatim rather than reconstruct
them. Re-verification against the fixed write path found this closed most, but not all, of the
gap: across two independent no-op re-runs (120 cached-control opportunities total), one control
(SC-2) still had its `confidence` text paraphrased by its family subagent despite the explicit
instruction — LLM prompting reduces but does not guarantee byte-for-byte fidelity, the same
class of unreliability that motivated write-fragment.py in the first place. The fix: extend the
same script-enforcement principle to the merge step. A new `merge-state.py` script becomes the
sole writer of `security/assessment-state.yaml`; for any control a fragment marks
`"cached": true`, the script ignores whatever the fragment wrote for `finding`/`confidence`/
`files_read` and instead copies those fields from the *pre-run* `assessment-state.yaml` itself —
so no LLM ever gets a chance to reword them. The script also performs the (fully mechanical)
plausibility check, so it remains the sole writer of the state file end-to-end — nothing is
hand-edited into it afterward.

**Files:**
- Modify: `skills/itsg-33-assess/scripts/write-fragment.py` (accept an optional `cached: bool`
  field per control, pass it through unchanged)
- Modify: `skills/itsg-33-assess/scripts/test_write_fragment.py` (2 new tests for the `cached`
  field)
- Create: `skills/itsg-33-assess/scripts/merge-state.py`
- Create: `skills/itsg-33-assess/scripts/test_merge_state.py`
- Modify: `skills/itsg-33-assess/SKILL.md` (Step 4a cache-check wording, Step 4's fragment JSON
  schema example, Step 5's merge instructions)

**Interfaces:**
- Consumes: `security/.assessment-fragments/<family>.json` fragments from Task 4.5's
  write-fragment.py, and the pre-run `security/assessment-state.yaml` (if any).
- Produces: `security/assessment-state.yaml` (unchanged shape: `{last_run, controls: {<id>:
  {finding, confidence, files_read}}}`), written exclusively by `merge-state.py`.

- [ ] **Step 1: Write the failing tests for write-fragment.py's `cached` field**

Append to `skills/itsg-33-assess/scripts/test_write_fragment.py` (inside the `WriteFragmentTest`
class, alongside the existing tests):

```python
    def test_cached_true_is_valid(self):
        control = dict(VALID_CONTROL, cached=True)
        payload = {"family": "AU", "controls": {"AU-2": control}}
        result = self.run_script("AU", payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(self.output_path.read_text())
        self.assertTrue(written["controls"]["AU-2"]["cached"])

    def test_invalid_cached_type_fails(self):
        control = dict(VALID_CONTROL, cached="yes")
        payload = {"family": "AU", "controls": {"AU-2": control}}
        result = self.run_script("AU", payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cached", result.stderr.lower())
```

- [ ] **Step 2: Run to verify the new tests fail**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_write_fragment.py -v
```
Expected: `test_cached_true_is_valid` fails (KeyError or AssertionError — the script currently
drops unrecognized fields silently or the key isn't present); `test_invalid_cached_type_fails`
fails (script currently accepts anything since it doesn't check `cached` at all — exit code 0
instead of non-zero). All other tests still pass.

- [ ] **Step 3: Add `cached` field support to write-fragment.py**

In `skills/itsg-33-assess/scripts/write-fragment.py`, inside the `validate()` function, after the
existing `files_read` validation loop (right before the function returns), add:

```python
        if "cached" in control and not isinstance(control["cached"], bool):
            fail(f"{control_id}: 'cached' must be a boolean if present")
```

No other change is needed — `json.dump` in `main()` already serializes whatever keys are present
in `data`, so a `cached` key passes through to the output automatically once validation accepts
it.

- [ ] **Step 4: Run to verify all write-fragment.py tests pass**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_write_fragment.py -v
```
Expected: all 9 tests pass (7 original + 2 new).

- [ ] **Step 5: Write the failing tests for merge-state.py**

Create `skills/itsg-33-assess/scripts/test_merge_state.py`:

```python
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "merge-state.py"


class MergeStateTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.fragments_dir = Path(self.tmpdir.name) / "fragments"
        self.fragments_dir.mkdir()
        self.old_state_path = Path(self.tmpdir.name) / "old-state.yaml"
        self.new_state_path = Path(self.tmpdir.name) / "new-state.yaml"

    def write_fragment(self, family, controls):
        (self.fragments_dir / f"{family}.json").write_text(
            json.dumps({"family": family, "controls": controls})
        )

    def run_merge(self, profile="PBMM"):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.fragments_dir),
             str(self.old_state_path), str(self.new_state_path), profile],
            capture_output=True,
            text=True,
        )

    def read_new_state(self):
        return json.loads(self.new_state_path.read_text())

    def test_fresh_merge_no_old_state(self):
        self.write_fragment("AU", {
            "AU-2": {"finding": "Fail", "confidence": "no audit logging found",
                      "files_read": {"k8s/deployment.yaml": "a" * 64}},
        })
        self.write_fragment("RA", {
            "RA-5": {"finding": "Pass", "confidence": "scanner runs on every PR",
                      "files_read": {}},
        })
        result = self.run_merge()
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.read_new_state()
        self.assertIn("last_run", state)
        self.assertEqual(state["controls"]["AU-2"]["finding"], "Fail")
        self.assertEqual(state["controls"]["RA-5"]["finding"], "Pass")

    def test_cached_control_uses_old_state_value_not_fragment(self):
        self.old_state_path.write_text(json.dumps({
            "last_run": "2026-01-01T00:00:00+00:00",
            "controls": {
                "SC-2": {"finding": "Pass", "confidence": "TRUE ORIGINAL TEXT",
                          "files_read": {"k8s/deployment.yaml": "b" * 64}},
            },
        }))
        self.write_fragment("SC", {
            "SC-2": {"finding": "Pass", "confidence": "a paraphrased rewording",
                      "files_read": {"k8s/deployment.yaml": "b" * 64}, "cached": True},
        })
        result = self.run_merge()
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.read_new_state()
        self.assertEqual(state["controls"]["SC-2"]["confidence"], "TRUE ORIGINAL TEXT")

    def test_cached_control_missing_old_entry_fails(self):
        self.write_fragment("SC", {
            "SC-2": {"finding": "Pass", "confidence": "whatever",
                      "files_read": {}, "cached": True},
        })
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sc-2", result.stderr.lower())
        self.assertIn("cached", result.stderr.lower())

    def test_duplicate_control_across_fragments_fails(self):
        self.write_fragment("AU", {
            "AU-2": {"finding": "Fail", "confidence": "x", "files_read": {}},
        })
        self.write_fragment("SI", {
            "AU-2": {"finding": "Pass", "confidence": "y", "files_read": {}},
        })
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("au-2", result.stderr.lower())

    def test_malformed_fragment_json_fails(self):
        (self.fragments_dir / "AU.json").write_text("{not valid")
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("json", result.stderr.lower())

    def test_malformed_old_state_fails(self):
        self.old_state_path.write_text("{not valid")
        self.write_fragment("AU", {
            "AU-2": {"finding": "Fail", "confidence": "x", "files_read": {}},
        })
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("json", result.stderr.lower())

    def test_no_fragments_found_fails(self):
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no fragment", result.stderr.lower())

    def test_plausibility_check_triggers_for_all_na_sc_and_ia(self):
        self.write_fragment("SC", {
            "SC-2": {"finding": "Not Assessable", "confidence": "x", "files_read": {}},
        })
        self.write_fragment("IA", {
            "IA-2": {"finding": "Not Assessable", "confidence": "y", "files_read": {}},
        })
        result = self.run_merge(profile="PBMM")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.read_new_state()
        self.assertIn("PLAUSIBILITY-WARNING", state["controls"])
        self.assertEqual(state["controls"]["PLAUSIBILITY-WARNING"]["finding"], "Not Assessable")

    def test_plausibility_check_not_triggered_for_non_pbmm_profile(self):
        self.write_fragment("SC", {
            "SC-2": {"finding": "Not Assessable", "confidence": "x", "files_read": {}},
        })
        self.write_fragment("IA", {
            "IA-2": {"finding": "Not Assessable", "confidence": "y", "files_read": {}},
        })
        result = self.run_merge(profile="unclassified")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.read_new_state()
        self.assertNotIn("PLAUSIBILITY-WARNING", state["controls"])

    def test_plausibility_check_not_triggered_when_some_pass(self):
        self.write_fragment("SC", {
            "SC-2": {"finding": "Pass", "confidence": "x", "files_read": {}},
        })
        self.write_fragment("IA", {
            "IA-2": {"finding": "Not Assessable", "confidence": "y", "files_read": {}},
        })
        result = self.run_merge(profile="PBMM")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.read_new_state()
        self.assertNotIn("PLAUSIBILITY-WARNING", state["controls"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 6: Run to verify the merge-state.py tests fail**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_merge_state.py -v
```
Expected: all 10 tests error (`FileNotFoundError` — `merge-state.py` does not exist yet).

- [ ] **Step 7: Implement merge-state.py**

Create `skills/itsg-33-assess/scripts/merge-state.py`:

```python
#!/usr/bin/env python3
"""Merge itsg-33-assess family fragments into assessment-state.yaml.

Usage: merge-state.py <fragments-dir> <old-state-path> <new-state-path> <profile>

Reads every non-scratch JSON fragment in <fragments-dir> (files written by
write-fragment.py) and merges them into a single controls map. This script
is the sole writer of assessment-state.yaml: for any control a fragment
marks "cached": true, the finding/confidence/files_read already stored in
<old-state-path> are used verbatim, discarding whatever the fragment wrote
for those fields, so a no-op re-run cannot drift stored text regardless of
what an individual family subagent produced.

<old-state-path> may not exist (fresh run); it is then treated as having no
prior controls. <profile> drives the (fully mechanical) plausibility check.
<new-state-path> may be the same path as <old-state-path> for an in-place
update — the old file is fully read before the new one is written.
"""
import glob
import json
import os
import sys
from datetime import datetime, timezone

REQUIRED_STATE_FIELDS = ["finding", "confidence", "files_read"]


def fail(message):
    print(f"merge-state: {message}", file=sys.stderr)
    sys.exit(1)


def load_old_state(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        fail(f"existing state file {path} is not valid json: {e}")
    return data.get("controls", {}) or {}


def load_fragments(fragments_dir):
    paths = sorted(
        p for p in glob.glob(os.path.join(fragments_dir, "*.json"))
        if not p.endswith(".input.json")
    )
    if not paths:
        fail(f"no fragment files found in {fragments_dir}")

    merged = {}
    for path in paths:
        try:
            with open(path) as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            fail(f"fragment {path} is not valid json: {e}")

        family = data.get("family", os.path.splitext(os.path.basename(path))[0])
        for control_id, control in data.get("controls", {}).items():
            if control_id in merged:
                fail(f"control {control_id} appears in more than one fragment "
                     f"(duplicate found in {path}, family {family})")
            merged[control_id] = control
    return merged


def resolve_control(control_id, control, old_controls):
    if control.get("cached"):
        old = old_controls.get(control_id)
        if old is None:
            fail(f"{control_id}: marked cached but has no prior entry in the existing state file")
        return {field: old[field] for field in REQUIRED_STATE_FIELDS}
    return {field: control[field] for field in REQUIRED_STATE_FIELDS}


def apply_plausibility_check(controls, profile):
    if profile != "PBMM":
        return

    def all_not_assessable(prefix):
        matching = {cid: c for cid, c in controls.items() if cid.startswith(prefix + "-")}
        return bool(matching) and all(c["finding"] == "Not Assessable" for c in matching.values())

    if all_not_assessable("SC") and all_not_assessable("IA"):
        controls["PLAUSIBILITY-WARNING"] = {
            "finding": "Not Assessable",
            "confidence": (
                "PBMM declared but no encryption, auth, or network config was found. "
                "Verify the repo contains the relevant IaC or manifests, or that the "
                "system boundary is correctly scoped."
            ),
            "files_read": {},
        }


def main():
    if len(sys.argv) != 5:
        fail("usage: merge-state.py <fragments-dir> <old-state-path> <new-state-path> <profile>")
    fragments_dir, old_state_path, new_state_path, profile = sys.argv[1:5]

    old_controls = load_old_state(old_state_path)
    fragment_controls = load_fragments(fragments_dir)

    merged = {}
    for control_id, control in fragment_controls.items():
        merged[control_id] = resolve_control(control_id, control, old_controls)

    apply_plausibility_check(merged, profile)

    new_state = {
        "last_run": datetime.now(timezone.utc).isoformat(),
        "controls": merged,
    }
    with open(new_state_path, "w") as f:
        json.dump(new_state, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"merge-state: wrote {len(merged)} controls to {new_state_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 8: Run to verify all merge-state.py tests pass**

```bash
cd /home/bernard/github/itsg-33-skill && python3 skills/itsg-33-assess/scripts/test_merge_state.py -v
```
Expected: all 10 tests pass.

- [ ] **Step 9: Update SKILL.md Step 4a's cache-check wording**

Replace the current Step 4a paragraph (the one added by Task 4.5, starting `Read
security/assessment-state.yaml. For each file listed...` through `...Skip to next control.`)
with:

```markdown
**4a. Cache check**
Read `security/assessment-state.yaml`. For each file listed under this control's
`files_read`, hash the current content and compare to the stored hash. If all hashes match,
this control is cached: set `"cached": true` on its fragment entry (Step 4's write-up below),
and do not rewrite its evidence card. `merge-state.py` (Step 5) is the sole authority for a
cached control's `finding`, `confidence`, and `files_read` in `assessment-state.yaml` — it
always uses the values already stored there, discarding whatever you write for these fields
on a cached control, so you do not need to reproduce them precisely; carrying forward your
best-available copy is enough. The remaining fragment fields (`risk_summary`,
`implementation_approach`, `evidence_artefacts`, `client_responsibility`) are never read for a
cached control either, since its evidence card is not rewritten — a short placeholder such as
`"(cached — see evidence card)"` is fine. Skip to next control.
```

- [ ] **Step 10: Update SKILL.md's fragment JSON schema example**

In Step 4's fragment-write block (the `json` code fence showing the scratch input file shape),
add the optional `cached` field to the per-control example:

```markdown
```json
{
  "family": "<family>",
  "controls": {
    "<control-id>": {
      "finding": "<Pass | Fail | Not Assessable>",
      "confidence": "<string>",
      "risk_summary": "<string>",
      "implementation_approach": "<string>",
      "evidence_artefacts": ["<relative path>", "..."],
      "client_responsibility": "<string>",
      "files_read": {"<relative path>": "<sha256>"},
      "cached": true
    }
  }
}
```
(Omit `"cached"` entirely for a control that was freshly assessed this run — only set it to
`true` for a cache hit per Step 4a.)
```

- [ ] **Step 11: Update SKILL.md Step 5's merge instructions**

Replace the current Step 5 section body (from `Once all 9 fragments exist...` through the
`Completion:` line) with:

```markdown
Once all 9 fragments exist in `security/.assessment-fragments/`:

1. Run:
   ```bash
   python3 skills/itsg-33-assess/scripts/merge-state.py \
     security/.assessment-fragments \
     security/assessment-state.yaml \
     security/assessment-state.yaml \
     <profile>
   ```
   (`<profile>` is the profile from Step 1, e.g. `PBMM`.) This script is the sole writer of
   `security/assessment-state.yaml`, including the plausibility check below — nothing is
   hand-edited into this file afterward. For any control a fragment marks `"cached": true`, it
   uses the `finding`/`confidence`/`files_read` already stored in the pre-run
   `security/assessment-state.yaml` verbatim, discarding whatever the fragment wrote for those
   fields. For every other control, it takes `finding`/`confidence`/`files_read` directly from
   the fragment.

   If this exits non-zero, its stderr names exactly what is wrong: a control present in more
   than one fragment, a control marked cached with no prior entry to carry forward, or a
   fragment/existing-state file that isn't valid JSON. Treat this as a "malformed output" case
   per Step 4's failure handling — if the cause clearly traces to one family's fragment, retry
   that family's subagent once and re-run this step; otherwise abort the entire run, report why,
   and leave `security/.assessment-fragments/` in place for debugging.

2. Confirm every control in `controls.md` appears in the merged `security/assessment-state.yaml`
   exactly once. (`merge-state.py` only guards against a control appearing in *more than one*
   fragment; a control missing from *every* fragment is not something the script can detect,
   since it doesn't know the full control catalogue — check this against `controls.md`
   directly.) A control missing from all fragments is treated as a subagent failure per Step 4's
   failure handling: retry that family once, then re-run this step.

3. Delete `security/.assessment-fragments/`.

Completion: `security/assessment-state.yaml` contains an entry for every control in
`controls.md`; the fragment directory no longer exists.
```

(The plausibility check that previously appeared as this section's step 3 is now performed
inside `merge-state.py` itself — see Step 7 above — so it is removed from this prose list rather
than duplicated.)

- [ ] **Step 12: Consistency check (grep)**

```bash
grep -n "merge-state.py" skills/itsg-33-assess/SKILL.md
```
Expected: at least one occurrence (Step 5's invocation).

```bash
grep -n "PLAUSIBILITY-WARNING" skills/itsg-33-assess/SKILL.md
```
Expected: zero occurrences remain in prose form outside of anything referencing the script's
behavior — the synthetic-finding *logic* now lives solely in `merge-state.py`; SKILL.md no
longer contains hand-edit instructions for it. (If this grep still shows a standalone
instruction telling the orchestrator to hand-append the warning, that step wasn't fully
replaced — fix it.)

- [ ] **Step 13: Commit**

```bash
git add skills/itsg-33-assess/scripts/write-fragment.py \
        skills/itsg-33-assess/scripts/test_write_fragment.py \
        skills/itsg-33-assess/scripts/merge-state.py \
        skills/itsg-33-assess/scripts/test_merge_state.py \
        skills/itsg-33-assess/SKILL.md
git commit -m "$(cat <<'EOF'
Enforce cached-control fields at merge time via merge-state.py

Re-verification after write-fragment.py found that prompting alone
("copy confidence verbatim") still let one subagent paraphrase a
cached control's confidence text across two independent no-op re-run
tests — LLM instruction-following reduces but doesn't guarantee
byte-for-byte fidelity. merge-state.py is now the sole writer of
assessment-state.yaml: for any control a fragment marks cached, it
discards whatever the fragment wrote for finding/confidence/files_read
and copies those fields from the pre-run state file instead, so no
LLM gets a chance to reword them. The (fully mechanical) plausibility
check moves into the script too, so nothing is hand-edited into the
state file after the script runs.

Part of #15.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Re-verify end to end against a fresh scratch copy**

```bash
rm -rf /tmp/itsg33-verify-pass1
cp -r /home/bernard/github/itsg-33-skill/test/fixtures/sample-app /tmp/itsg33-verify-pass1
```

Dispatch a fresh init+assess (per Task 3 Step 2's pattern), then immediately a no-op re-run
(per Task 4 Steps 1-5's pattern) against this new copy, using the now-updated SKILL.md. Confirm:
zero fragment/merge validation failures across both runs, zero evidence-card mtime changes on
the no-op re-run, every cached control's `confidence` in the resulting `assessment-state.yaml`
is byte-identical to the fresh run's value (verify this directly by diffing the two state
files' `controls:` maps outside of `last_run` — do not rely solely on a subagent's self-report),
and `.assessment-fragments/` is absent after both runs. This replaces the old
`/tmp/itsg33-verify-pass1` state as the baseline Task 5 continues from.

---

### Task 5: Verification Pass 3 — changed-file re-assessment

**Files:** None modified in this repo. Modifies a file inside the `/tmp/itsg33-verify-pass1`
scratch copy only.

**Interfaces:**
- Consumes: the `/tmp/itsg33-verify-pass1` state left by Task 4.

- [ ] **Step 1: Modify one fixture file in the scratch copy**

Read `/tmp/itsg33-verify-pass1/k8s/rbac.yaml`, remove the `cluster-admin` binding it contains
(the deliberate AC-6 finding from `expected-findings.yaml`), and write the file back.

- [ ] **Step 2: Dispatch an orchestrator agent to re-run the Assess branch**

Same as Task 4 Step 2, pointed at `/tmp/itsg33-verify-pass1` after the edit.

- [ ] **Step 3: Verify only the AC family (and any other family whose controls match
`k8s/rbac.yaml`) was re-assessed**

Ask the dispatched orchestrator to report, per family, whether Step 4a's cache check hit or
missed for each control. Confirm: AC-6 (and any other control whose `files_read` includes
`k8s/rbac.yaml`) shows a fresh (non-cached) run; every control in the other 8 families that
don't reference `k8s/rbac.yaml` shows `cached`.

- [ ] **Step 4: Verify the updated finding**

Read the new `/tmp/itsg33-verify-pass1/security/assessment-state.yaml`. Confirm AC-6's finding
changed from `Fail` (removing the cluster-admin binding should flip it to `Pass` or
`Not Assessable`, per the rubric) and that all other controls' findings are unchanged from
Task 4's result.

No commit for this task.

---

### Task 6: Fix any discrepancies found, final commit

**Files:**
- Modify (only if Tasks 3-5 found mismatches): `skills/itsg-33-assess/controls.md` and/or
  `skills/itsg-33-assess/SKILL.md`'s Step 4c rubric (the copy inside the new Step 4 from Task 1)

**Interfaces:** N/A (no new interfaces; this task only corrects rubric wording if needed).

- [ ] **Step 1: Review discrepancy list from Tasks 3-5**

If Tasks 3-5 found zero mismatches, skip straight to Step 4 (final commit — there may be nothing
to commit here since Tasks 1-2 already committed the restructuring).

If mismatches exist, for each one: identify whether it's caused by (a) a genuine rubric gap
(the same class of issue that commit 21bd511 fixed) or (b) an error introduced by the
Step 4/5 restructuring itself (e.g. a family subagent's prompt is missing context it needs, a
fragment schema mismatch, a merge bug).

- [ ] **Step 2: Fix restructuring-caused bugs first**

If any mismatch traces to (b), fix the specific instruction in `SKILL.md`'s Step 4 or 5 (e.g. a
missing field in the dispatch-prompt requirements list, an ambiguous merge instruction). Re-run
the specific verification pass from Tasks 3-5 that caught it to confirm the fix.

- [ ] **Step 3: Fix genuine rubric gaps generalizably**

For any mismatch traced to (a), edit `controls.md` and/or the Step 4c rubric text with a
**generalizable principle**, phrased so it would apply to any target codebase — never a fixture-
specific hardcoded answer (e.g. "control AC-6 in sample-app should be Pass" is not an acceptable
fix; a rewording of a Pass/Fail signal or the cascading rule that produces the correct answer
*because* it's a more accurate general rule is). Re-run the specific verification pass that
caught it.

- [ ] **Step 4: Final commit**

```bash
git add skills/itsg-33-assess/SKILL.md skills/itsg-33-assess/controls.md
git status
```
If there are staged changes from Steps 2-3:
```bash
git commit -m "$(cat <<'EOF'
Fix reasoning gaps found verifying parallel-fan-out itsg-33-assess (#15)

Re-ran the three-pass fixture verification from issue #12 against the
restructured (family-fan-out) Step 4/5. [Replace this line with a
one-line summary of what was actually found and fixed, or state
"No discrepancies found — fan-out produced identical findings to the
sequential baseline" if Tasks 3-5 passed clean.]

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
If there is nothing staged (Tasks 3-5 found no discrepancies), skip the commit — Tasks 1-2's
commits already captured the full change, and this step is where you report the verification
result to the user instead.

---

## Self-Review Notes

- **Spec coverage:** Step 4 dispatch + subagent contract (spec §"Step 4"/§"Section 2") → Task 1.
  Fragment schema + merge + plausibility-check relocation + failure/abort handling (spec
  §"Step 5"/§"Section 3") → Tasks 1 (failure handling lives in Step 4) and 2 (merge). Renumbering
  and doc changes (spec §"Section 4") → Task 2. Three-pass re-verification (spec
  §"Verification plan") → Tasks 3-5. Generalizable-fix discipline (standing project preference,
  referenced in Global Constraints) → Task 6.
- **Placeholder scan:** the only bracketed placeholder in this plan is the commit-message line in
  Task 6 Step 4, which is intentionally conditional on Tasks 3-5's actual findings (unknowable
  until those tasks run) — every other step has literal, complete content.
- **Type/schema consistency:** the fragment schema in Task 1 (`family`, `controls: {finding,
  confidence, risk_summary, implementation_approach, evidence_artefacts, client_responsibility,
  files_read}`) matches what Task 2's merge step reads, and the merged `assessment-state.yaml`
  shape (`last_run`, `controls: {finding, confidence, files_read}`) matches what Step 4a's cache
  check (Task 1) reads back on the next run.
