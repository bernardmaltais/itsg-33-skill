# Verify itsg-33-remediate against the fixture repo

**Issue:** #14 — Verify itsg-33-remediate against fixture repo
**Status:** Approved for planning
**Date:** 2026-07-15

## Background

`itsg-33-remediate` (`skills/itsg-33-remediate/SKILL.md`, drafted for issue #13) is a
prompt-driven Claude Code skill: its `SKILL.md` is instructions an invoking agent follows
directly, the same style as `itsg-33-assess`. It has never been run end-to-end. Issue #14 is its
primary acceptance gate, mirroring issue #12's role for `itsg-33-assess`: run the skill against
`test/fixtures/sample-app/` and confirm the full ten-step remediation flow (load gap → sort →
present → test baseline → propose fix → branch → verify green → draft PR → POA&M update →
continue/stop) works for a real gap, using AC-6 (the fixture's deliberate cluster-admin
ClusterRoleBinding) as the test case.

The fixture directory itself is not a git repository and has no GitHub remote, and per the
constraint carried over from issue #15's verification work, `test/fixtures/sample-app/` must not
gain a checked-in `security/` folder — all runtime artifacts (gap issues, evidence cards,
assessment state, git branches) belong in a disposable scratch copy, not the repo fixture itself.

## Decisions

### Tracker mode: local only, no real GitHub side effects

`itsg-33-assess`'s own tracker-mode detection is "GitHub remote present → `github`; absent →
`local`" (`skills/itsg-33-assess/SKILL.md` Step 1). A scratch copy of the fixture, `git init`'d
with no remote, auto-detects as `local` mode under this same rule — so no real GitHub issues or
PRs are created during verification. This means the ticket's literal acceptance-criteria wording
("`Closes #<AC-6-gap-issue>` in the body") — which only applies to `itsg-33-remediate`'s
GitHub-mode PR-body template — does not apply verbatim; local mode's actual template line is
`Resolves local gap: security/gaps/AC-6.md`, and that is what gets verified instead.

### Gap sourcing: targeted AC-family dispatch, not a full 9-family assess run

The AC-6 gap needs to exist "from a previous assess run" before remediate can consume it. Rather
than running all 9 `itsg-33-assess` family subagents (issue #15's fixture-verification pattern,
useful there because it verified assess's own full behavior), this verification only needs the AC
family's output. A single subagent runs assess's Step 4 AC-family contract against the scratch
copy, followed by `write-fragment.py` and `merge-state.py` (assess Step 5), followed by assess
Step 6 (gap issue creation, local mode → `security/gaps/AC-6.md` + `security/evidence/AC-6.md`).
The other 8 families are not dispatched — this verification is scoped to `itsg-33-remediate`, not
a second full run of `itsg-33-assess`.

### Fixture gains a minimal test (Makefile + shell script)

`test/fixtures/sample-app/` currently has no test runner at all — none of
`itsg-33-remediate`'s Step 4 detection signals (`package.json`, `go.mod`,
`pytest.ini`/`setup.py`/`pyproject.toml`, `Makefile` with a `test` target) are present. Per issue
#14's own fallback instruction ("add a minimal test... to the fixture as part of this ticket"),
this verification adds:

- `test/fixtures/sample-app/Makefile` — a `test:` target that runs `check-rbac.sh`.
- `test/fixtures/sample-app/check-rbac.sh` — greps `k8s/rbac.yaml` for a `ClusterRoleBinding`
  whose `roleRef.name` is `cluster-admin`; exits 1 (fail) if one is found, 0 (pass) otherwise.
  Generic to the anti-pattern (any cluster-admin binding), not to this fixture's specific
  resource name — reusable as a real regression check, not a throwaway verification prop.

This is a permanent addition to the checked-in fixture (unlike the scratch `security/` state),
since it's the kind of test any of the fixture's future callers would want.

### AC-6 fix content: let remediate's own Step 5 decide

The fixture's `k8s/rbac.yaml` currently grants `cluster-admin` to the `sample-app` service
account via a `ClusterRoleBinding`. Issue #14 accepts either removing or scoping this binding.
Rather than pre-deciding the fix content, the verification lets the dispatched
`itsg-33-remediate` walkthrough produce its own Step 5 proposal (that reasoning step is itself
part of what #14 verifies) and confirms `check-rbac.sh` passes afterward, whatever the specific
edit turns out to be.

### Step 8 discrepancy: `gh pr create` unconditionally, regardless of tracker mode

`itsg-33-remediate/SKILL.md` Step 8 currently always runs `gh pr create --draft ...`, with only
the PR *body's* closing line varying by tracker mode. Against the scratch copy (no GitHub
remote), this command has nothing to create a PR against and will fail. This is expected to
surface during verification, not treated as a fixture problem — it's a real gap in the skill:
nothing in Step 6 (branch) or Step 7 (verify green) depends on a remote existing, but Step 8 does,
and the skill never checks for one first.

**Fix (generalizable, applies to any no-remote repo, not just this fixture):** gate Step 8 on
remote presence using the same check assess's Step 1 already uses. If a usable remote exists,
Step 8 proceeds unchanged. If not, Step 8 stops after Step 7's green baseline: the fix stays
committed on its branch, and the skill tells the user no PR was opened because there is no
GitHub remote, deferring PR creation (and Step 9's `Remediation Ticket` POA&M link, which has
nothing to point at yet) until one exists. Step 8 and Step 9's completion criteria get an
explicit "or: no remote, PR deferred" branch to match.

## Verification checklist

Directly from issue #14's 11 numbered verification steps and 8 acceptance criteria — each
checked explicitly against real file contents (evidence card, gap file, `assessment-state.yaml`,
git branch/log), not the dispatched agent's self-report, matching the independent-verification
discipline issue #15's progress log used throughout:

1. AC-6 gap file/evidence-card exist after the targeted AC-family assess dispatch.
2. `itsg-33-remediate` is invoked against the scratch copy.
3. AC-6 is presented as the first (only) gap — trivially true with one gap, but Step 2's P1-first
   sort logic is still exercised if the AC dispatch happens to also produce other Fail findings
   in-family (e.g. none expected per `expected-findings.yaml`, but not assumed in advance).
4. `make test` is detected and run as the baseline (fails: cluster-admin present).
5. Baseline captured before Step 5's fix proposal.
6. Fix proposal approved.
7. Branch `itsg33/fix/AC-6` created from the correct base commit.
8. The cluster-admin binding is removed or scoped in the committed fix.
9. `make test` passes on the branch.
10. Draft-PR path: since no remote exists, confirm the *fixed* Step 8 correctly stops and reports
    "no remote, PR deferred" instead of failing on `gh pr create` — this replaces the literal
    "draft PR opened" criterion, per the tracker-mode decision above.
11. `security/evidence/AC-6.md`'s `Remediation Ticket` field: not set (no PR exists yet) — confirms
    Step 9's deferred-POA&M branch, rather than a stale/incorrect ticket reference being written.

## Error handling / discrepancy discipline

Any mismatch between expected and actual behavior found during the walkthrough is classified,
same as issue #15's Task 6:
- **(a) Genuine `itsg-33-remediate` gap** → fixed generalizably in `SKILL.md`, phrased so it
  applies to any repo/gap, never hardcoded to this fixture or to AC-6 specifically.
- **(b) Artifact of this verification's own scratch harness** (e.g. a dispatch-prompt omission,
  not a skill-instruction gap) → fixed in the harness/dispatch prompt, not in `SKILL.md`.

The Step 8/`gh pr create` issue above is already known to be category (a) and is fixed as part of
this work rather than merely documented, since it's fully specified and low-risk (a single
conditional gate).

## Out of scope

- Running `itsg-33-assess`'s other 8 control families against the fixture (already covered by
  issue #12/#15).
- Exercising `itsg-33-remediate`'s GitHub tracker mode for real (would require creating a
  disposable GitHub repo; explicitly declined in favor of local-mode-only verification).
- Gap-file lifecycle cleanup when a finding later flips Pass (flagged as a separate future issue
  by #15's Task 5 side-finding; unrelated to remediate's own flow).
