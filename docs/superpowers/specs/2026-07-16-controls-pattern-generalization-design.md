# Generalizing controls.md File patterns beyond Terraform/K8s/GitHub Actions

**Status:** Approved for planning
**Date:** 2026-07-16

## Background

`itsg-33-assess`'s `SKILL.md` Step 4b glob-matches each control's **File patterns** line
(`controls.md`) against the repo. A zero-match glob short-circuits straight to **Not
Assessable** — there is no fallback. Nearly every control's patterns are hardcoded to one
tech stack: Terraform for IaC, Kubernetes YAML for orchestration, GitHub Actions for CI/CD,
and (for SI-10/SI-11/SI-16) exactly six languages (Go, Python, JS, TS, Java, C#). A repo
built on Pulumi, CloudFormation/SAM, Bicep, Ansible, GitLab CI, Azure Pipelines, ECS/Cloud
Run, or written in Rust, Kotlin, PHP, Ruby, Swift, C++, or Scala would have most AC/AU/IA/SC/
CM/SI evidence silently marked Not Assessable even where the equivalent control is fully
implemented — a false negative on the assessment, not a true gap.

Discussed three fixes: broaden the glob lists only (cheap, but still an enumeration that
lags the next new tool); replace patterns with pure content-based judgment per control (most
future-proof, but every one of ~40 controls would independently re-scan the whole repo —
slow, redundant, unpredictable, harder to audit); or a hybrid. Went with the hybrid.

## Decision

Two changes, one to `controls.md` and one to `SKILL.md`, addressing the two failure modes
identified together (both language-specific and infra-tool-specific patterns).

## Part 1 — `controls.md`: shared pattern families

Add a **Common Pattern Families** section directly under "How to read an entry", defining
three reusable, named glob sets:

- **`{IaC}`** — `**/*.tf`, `**/*.bicep`, `**/*.template.yaml`, `**/*.template.json`,
  `**/cloudformation/**`, `**/Pulumi.*.yaml`, `**/*.pulumi.*`, `**/playbook*.yml`,
  `**/*.ansible.yml`
- **`{CI/CD}`** — `.github/workflows/*.yaml`, `.gitlab-ci.yml`, `azure-pipelines*.yml`,
  `.circleci/config.yml`, `Jenkinsfile`
- **`{App source}`** — `**/*.go`, `**/*.py`, `**/*.js`, `**/*.ts`, `**/*.java`, `**/*.cs`,
  `**/*.rs`, `**/*.rb`, `**/*.php`, `**/*.kt`, `**/*.swift`, `**/*.cpp`, `**/*.scala`

Every control whose **File patterns** line currently contains bare `**/*.tf` replaces it
with `{IaC}`, keeping any control-specific extras (e.g. `**/rbac*.yaml`, `**/bastion*.tf`)
as literal patterns alongside it — those aren't shared across controls, so they stay
inline. Every control whose patterns include `.github/workflows/*.yaml` replaces it with
`{CI/CD}`. SI-10, SI-11, and SI-16 replace their six-language enumeration with
`{App source}`.

This keeps individual control entries concrete and human-readable (a family name plus
whatever's control-specific), while making the enumeration maintainable in one place: adding
support for a new IaC tool or language means editing one family definition, not sweeping
every control that references it.

The **How to read an entry** section gains one line explaining that `{Name}` in a File
patterns line expands to the corresponding Common Pattern Families glob set.

## Part 2 — `SKILL.md`: a fallback sweep before Not Assessable

Reuses the *existing* Step 2 fingerprint as the single repo-wide sweep, rather than having
each of ~40 controls independently scan the tree.

**Step 2 (Fingerprint tech stack)** changes from a fixed yes/no table to a broader survey:
same known-signal table, expanded to also recognize the tools now named in the pattern
families (Pulumi, Bicep, CloudFormation, Ansible, GitLab CI, Azure Pipelines, Rust, Ruby,
PHP, Kotlin, Swift, C++, Scala), plus a catch-all: record any other distinct top-level file
extensions found in the repo that aren't already covered, so an entirely unanticipated stack
still shows up in the survey passed to subagents.

**Step 4b (Read relevant files)** changes from "no glob match → Not Assessable" to:

1. Glob the control's **File patterns** (family-expanded) against the repo.
2. If at least one file matches, read and proceed to 4c as today.
3. If none match, check the Step 2 survey for a tool/language present in the repo that this
   control's patterns didn't anticipate (e.g., survey shows `.rs` files but the control's
   patterns only cover `{App source}` as currently enumerated — meaning the language was
   later added to the repo but not yet to the family; or survey shows Pulumi/Bicep files for
   an `{IaC}`-tied control that somehow still didn't match). If such a signal exists, glob
   for that tool's characteristic files and read them, then proceed to 4c.
4. Only if step 3 also turns up nothing is the finding **Not Assessable** — record
   `reason: no matching files (including tech-stack fallback)`.

This is a fast reasoning cross-check against an already-computed survey, not a new per-
control repo scan — the expensive work (walking the tree) happens once in Step 2, not once
per control in Step 4b.

## Verification plan

No automated test suite covers `SKILL.md`/`controls.md` prose (LLM instructions, not
executable code — same posture as this repo's other recent design specs). Verification is:

1. **Consistency check** — grep `controls.md` after edits to confirm no bare `**/*.tf`,
   `.github/workflows/*.yaml`, or six-language enumeration remains outside the Common Pattern
   Families definitions themselves.
2. **Fixture dry run** — run `itsg-33-assess` against `test/fixtures/sample-app/` (or
   equivalent) before and after the edit to confirm findings are unchanged for the existing
   Terraform/K8s/GitHub-Actions fixture (the family expansion is additive, so this should be
   a no-op for the current fixture set).
3. **Structural check** — confirm Step 4b's new fallback branch has an explicit completion
   criterion and failure mode (Not Assessable + reason string), matching this repo's existing
   convention of every step ending in a stated completion criterion.

## Out of scope

- Adding a fixture repo in a non-Terraform/non-K8s stack to exercise the fallback path live —
  noted as a good follow-up, not required to land this change.
- Fully content-based (glob-free) matching — explicitly rejected in favor of the hybrid.
- Exhaustively enumerating every possible IaC tool/language in the pattern families — the
  fallback sweep exists precisely so the families don't need to be exhaustive.
