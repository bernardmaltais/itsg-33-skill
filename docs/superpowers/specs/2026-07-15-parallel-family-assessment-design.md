# Parallel family-fan-out assessment for itsg-33-assess

**Issue:** #15 — Fire itsg-33-assess subagents per control family to speed up testing
**Status:** Approved for planning
**Date:** 2026-07-15

## Background

`itsg-33-assess` is a prompt-driven Claude Code skill (not code): `SKILL.md` is a set of
instructions the invoking agent follows directly. Its Assess branch currently walks all 60
controls in `controls.md` sequentially (Step 4), which makes a full run — and therefore every
iteration on rubric fixes verified against `test/fixtures/sample-app/` — a single long agent
turn. There is no separate test-harness script; verification is done by dispatching Agent-tool
subagents that execute the SKILL.md's instructions against the fixture (see commit 21bd511).

## Decision

Change the real `itsg-33-assess/SKILL.md` (not a test-harness-only optimization) so that Step 4
fans out to one subagent per control family, running always (no opt-in flag) — replacing the
sequential loop outright. This benefits both real end-user assessments and the fixture
verification loop that motivated the issue.

## Step structure

Step 4 ("Assess each control") is replaced by two steps:

### Step 4 — Dispatch family subagents

The orchestrating agent partitions `controls.md` by family prefix — AC, AU, IA, SC, CM, SI, SA,
CP, RA (all 9, including single-control RA) — and dispatches one subagent per family in a single
message (parallel Task/Agent tool calls). Every family gets a subagent every run, regardless of
whether any of its controls are dirty; pre-checking dirtiness would require the orchestrator to
duplicate 4a's hashing work just to decide whether to skip a subagent, which is more complexity
than the dispatch overhead it would save.

Each subagent's prompt includes:
- Active profile, `system_name`, `system_boundary`, tracker mode (from Step 1)
- The Step 2 detected-signal list
- A pointer to its family's slice of `controls.md`
- The evidence-card template (`evidence-card.md`)

Each subagent runs, for only its own family's controls:
- **4a** Cache check (reads `security/assessment-state.yaml`; read-only, safe to run
  concurrently across families)
- **4b** Read relevant files
- **4c** Reason (apply Pass/Fail signal rules from `controls.md`, unchanged from today)
- **4d** Record finding
- **6** Write evidence cards — for a cache-hit control, the finding is carried forward
  **without rewriting its evidence card** (preserves the incremental guarantee verified in
  issue #12 Pass 2: unchanged re-run touches no evidence card mtimes)

A subagent does **not** touch `assessment-state.yaml` directly, does not create gap issues, and
does not touch the report files. Instead it writes its results to a scratch fragment file:

```
security/.assessment-fragments/<family>.yaml
```

```yaml
family: AC
controls:
  AC-2:
    finding: Pass
    confidence: <string>
    risk_summary: <string>
    implementation_approach: <string>
    evidence_artefacts: [<path>, ...]
    client_responsibility: <string>
    files_read:
      <relative path>: <sha256>
  AC-3: { ... }
```

This is the same per-control shape already used in `assessment-state.yaml` today, namespaced per
family — the merge step is a flat concatenation, not a data transform.

**Failure handling:** if a subagent errors or returns malformed output, the orchestrator retries
that one family once. A second failure aborts the whole run with an explicit error naming the
failed family. No report is generated with silently-missing data; the previous
`assessment-state.yaml` and evidence cards are left untouched, and the fragment directory is left
in place for debugging.

### Step 5 — Merge state

Once all 9 fragments exist, the orchestrator:
1. Reads all fragments and confirms every control in `controls.md` is accounted for exactly
   once. A control missing from all fragments, or present in more than one, is treated the same
   as a subagent failure: retry that family once, then abort per the rule above.
2. Writes the combined `controls:` map plus a fresh `last_run` timestamp into
   `security/assessment-state.yaml`.
3. Runs the plausibility check (all-SC-and-IA-Not-Assessable → `PLAUSIBILITY-WARNING`) against
   the merged result, since it needs all SC/IA findings together and can't be evaluated by a
   single family in isolation.
4. Deletes `security/.assessment-fragments/`.

### Steps 6-9

Step 6 (evidence cards) moves into the per-family subagent contract above and is removed as a
standalone orchestrator step. Steps 7 (gap issues), 8 (Markdown report), 9 (HTML report) are
unchanged in content, but now run once, in the orchestrator, after the Step 5 merge — same as
they ran once after the old sequential loop today.

## Verification plan

Since this changes real assessment behavior (not just internal plumbing), re-run the same
three-pass verification from issue #12 against `test/fixtures/sample-app/`:

- **Pass 1 (fresh init+assess):** findings still match `expected-findings.yaml` — family
  fan-out should change *how* work is distributed, not *what* gets concluded.
- **Pass 2 (no-op incremental re-run):** no evidence card mtimes change; the fragment directory
  is absent afterward (cleaned up); `assessment-state.yaml` hashes stable.
- **Pass 3 (changed-file re-run):** changing one file causes only the owning family's subagent
  to redo that control; the other 8 families come back fully cached.

This re-verification is the acceptance gate for this change, matching how issue #12 verified the
original sequential design — `itsg-33-assess` is a prompt-driven skill, not code, so the gate is
a scripted human/agent verification pass rather than an automated test suite.

## Out of scope

- An opt-in/opt-out flag for parallel vs. sequential — this design always fans out.
- Any change to the Pass/Fail/Not-Assessable reasoning rubric in Step 4c — that rubric is
  unchanged; only its execution is distributed.
- A general-purpose test-harness script separate from the skill itself.
