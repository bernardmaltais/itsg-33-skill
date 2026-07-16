# Azure DevOps as a third tracker mode for itsg-33-assess / itsg-33-remediate

**Status:** Approved for planning
**Date:** 2026-07-16

## Background

`itsg-33-assess` and `itsg-33-remediate` currently support two tracker modes, auto-detected in
`itsg-33-assess`'s Init branch from `git remote -v`: `github` (gap issues as GitHub Issues, PRs via
`gh`) and `local` (gap issues as files under `security/gaps/`, no PR automation). The user wants a
third mode — `azure-devops` — so control gaps and remediation PRs can be tracked natively in Azure
Boards/Repos for repos hosted there, without hardcoding any org, tenant, or PAT the way the
existing private reference skills (`azure-devops-pr-quick-create`, `azure-devops-work-item-comment`)
do. Those reference skills are useful for their *mechanics* (which `az` subcommands actually work,
auth quirks) but are tied to one company's org/tenant/PAT env var names — not reusable as-is.

The user also asked that both the new Azure DevOps calls and the existing `gh` calls be wrapped in
bash scripts rather than constructed inline by the agent each run, to remove flag/quoting guesswork
and make every invocation deterministic — the same rationale behind this repo's existing
`write-fragment.py`/`merge-state.py` scripts, and behind the private reference skills' own
`add_comment.sh`/`create_work_item.sh` pattern.

All `az` command syntax below was verified against the current Microsoft Learn CLI reference
(`learn.microsoft.com/en-us/cli/azure/boards`, `.../repos`) rather than assumed from memory, per
standing instruction to validate version-specific facts before stating them.

## Decision

Add `tracker: azure-devops` as a third value alongside `github` and `local`, detected the same way
`github` is today (from the git remote), not as an independently configurable mode decoupled from
where the repo lives. Both skills gain a third branch at each tracker-dependent step, structurally
parallel to the existing two. All `gh` and `az` calls in every tracker-dependent step — including
the pre-existing GitHub-mode ones — move from inline agent-constructed commands into fixed bash
scripts, duplicated into each skill's own `scripts/` directory (see Script layout below) so each
skill folder stays independently portable.

## Config changes

`itsg-33-assess` Init Step 3 (Detect tracker mode) becomes:

| `git remote -v` contains | `tracker` |
|---|---|
| `github.com` | `github` |
| `dev.azure.com` | `azure-devops` |
| neither | `local` |

Init Step 4 (Write `security/itsg33.yaml`) gains, for `azure-devops` only, three extra fields —
needed because `az boards`/`az repos` subcommands require explicit `--org`/`--project`/
`--repository` flags (unlike `gh`, which infers these from the remote of the current working
directory), and because the scripts below take them as positional args rather than re-deriving them
from the remote on every call:

```yaml
tracker: azure-devops
ado_org: https://dev.azure.com/<org>
ado_project: <project>
ado_repo: <repo>
```

Parse these from the remote URL, handling both forms:
- HTTPS: `https://[<user>@]dev.azure.com/<org>/<project>/_git/<repo>`
- SSH: `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`

`github` and `local` modes are unchanged.

## Script layout

Both skills get a `scripts/` bash helper set. The set is duplicated across
`itsg-33-assess/scripts/` and `itsg-33-remediate/scripts/` (not shared via a cross-skill relative
path), so either skill folder can still be copied out of this repo as a standalone unit — matching
how the private reference skills exist as independent copies under `.claude/skills/`,
`.copilot/skills/`, `.skillpack/repos/...`.

Every script follows this repo's existing script contract (same as `write-fragment.py` /
`merge-state.py`): `set -euo pipefail`, `==>` progress lines to stderr, JSON parsing via `python3`
(already a hard dependency elsewhere in this repo), non-zero exit + a one-line stderr reason on any
failure so the calling SKILL.md step can surface it verbatim rather than needing to interpret raw
`az`/`gh` output. On success, a script prints only the ID(s)/URL the SKILL.md step needs next.

**GitHub scripts** (replace today's inline `gh` calls in both skills):

| Script | Args | Wraps | Used by |
|---|---|---|---|
| `gh-list-tagged-issues.sh` | `<label>` | `gh issue list --label <label> --state open --json number,title,body,labels` | assess Step 6 (dedup), remediate Step 1 |
| `gh-create-issue.sh` | `<title> <labels> <body-file>` | `gh issue create`, prints `<number> <url>` | assess Step 6, remediate Step 4 |
| `gh-create-pr.sh` | `<title> <body-file> [<closes-issue-number>]` | `gh pr create --draft`, appends a `Closes #<N>` line to the body when given, prints the PR URL | remediate Step 8 |

**Azure DevOps scripts:**

| Script | Args | Wraps | Used by |
|---|---|---|---|
| `ado-list-tagged-items.sh` | `<org> <project> <tag>` | `az boards query --wiql` for open items with the given tag, JSON out | assess Step 6 (dedup), remediate Step 1 |
| `ado-create-work-item.sh` | `<org> <project> <type> <title> <tags> <description-file>` | `az boards work-item create`, prints `<id> <url>` | assess Step 6, remediate Step 4 |
| `ado-create-pr.sh` | `<org> <project> <repo> <source-branch> <title> <body-file> <work-item-id> [<target-branch>]` | Auto-detects the default branch via `az repos show` when `<target-branch>` is omitted, then `az repos pr create --draft --work-items`, prints `<id> <url>` | remediate Step 8 |

Each `ado-*.sh` script's preamble checks `az extension list -o tsv --query
"[?name=='azure-devops']"` and runs `az extension add --name azure-devops -y` if empty, so the
extension-install prerequisite lives once per script rather than as a separate manual SKILL.md
step. Neither the `gh-*.sh` nor `ado-*.sh` scripts handle auth themselves — both assume an already
active `gh auth login` / `az login` session (existing behavior for `gh`; same posture extended to
`az`) and simply let the underlying CLI's own auth error surface on failure.

Local mode stays untouched — it's plain file read/write, nothing to script.

## itsg-33-assess Step 6 — Create gap issues

Both the GitHub and Azure DevOps branches now call scripts instead of building commands inline:

**GitHub branch:**
```bash
bash skills/itsg-33-assess/scripts/gh-list-tagged-issues.sh itsg-33:gap
# skip creation if the title already appears in the result
bash skills/itsg-33-assess/scripts/gh-create-issue.sh "<title>" "itsg-33:gap,<P1|P2|P3>" <body-file>
```

**Azure DevOps branch:**
```bash
bash skills/itsg-33-assess/scripts/ado-list-tagged-items.sh "<ado_org>" "<ado_project>" itsg-33:gap
# skip creation if the title already appears in the result
bash skills/itsg-33-assess/scripts/ado-create-work-item.sh "<ado_org>" "<ado_project>" Issue \
  "[itsg-33:gap] <Control ID> — <Control Name>" "itsg-33:gap; <P1|P2|P3>" <description-file>
```

Dedup semantics are unchanged from today: skip creation if a work item/issue with the same title
(`[itsg-33:gap] <Control ID> — <Control Name>`) already appears in the list.

Severity/identity encoding for Azure DevOps: a single `System.Tags` value holding both
`itsg-33:gap` and the severity (`P1`/`P2`/`P3`) as semicolon-separated tags — mirrors how GitHub
labels are used today, no separate field mapping.

Body content: same fields as before (control ID, finding, confidence note, recommended action,
evidence card path). For Azure DevOps, write the description file as simple HTML (`<p>`, `<ul>`,
`<code>`) — `System.Description` is a rich-text HTML field, not Markdown, unlike a GitHub issue
body or an Azure DevOps **PR** description (which does render Markdown).

## itsg-33-remediate changes

### Step 1 — Load gap issues

**GitHub branch** now calls `gh-list-tagged-issues.sh itsg-33:gap` in place of the inline `gh issue
list` invocation — same output shape as today.

**Azure DevOps branch:** call `ado-list-tagged-items.sh "<ado_org>" "<ado_project>" itsg-33:gap`,
then `az boards work-item show --id <id> --org "<ado_org>" -o json` per result for full field
values (a `show`-per-item step, not itself worth scripting since it's a single flag-free call).
Control ID/name are parsed from the title (`[itsg-33:gap] <Control ID> — <Control Name>` — same
format used to create it). Severity, confidence note, and recommended action still come from the
evidence card, exactly as they already do for both existing modes — the current SKILL.md's
rationale ("the evidence card is the only place severity is recorded in a form both tracker modes
can read the same way") extends unchanged to a third mode. Source reference becomes the work item
ID/URL (`<ado_org>/<ado_project>/_workitems/edit/<id>`).

The `itsg-33:gap` tag filter naturally excludes `itsg-33:needs-test`-tagged items, the same way
GitHub mode's `itsg-33:gap` label filter naturally excludes issues under the separate
`itsg-33:needs-test` label — no extra exclusion logic needed.

### Step 4 — needs-test task

**GitHub branch** now calls `gh-create-issue.sh "[itsg-33:needs-test] <control-id> — write failing
test" itsg-33:needs-test <body-file>` in place of the inline `gh issue create`.

**Azure DevOps branch:** `ado-create-work-item.sh "<ado_org>" "<ado_project>" Issue "[itsg-33:needs-test]
<control-id> — write failing test" itsg-33:needs-test <description-file>`.

### Step 8 — Open PR

Add a remote check for `dev.azure.com` alongside the existing "no remote" and GitHub checks in
this step.

**GitHub branch** now calls `gh-create-pr.sh "<title>" <body-file> <gap-issue-number>` in place of
the inline `gh pr create` — the script appends the `Closes #<N>` line itself.

**Azure DevOps branch:** `ado-create-pr.sh "<ado_org>" "<ado_project>" "<ado_repo>"
"<source-branch>" "<title>" <body-file> <work-item-id>` — target branch omitted, so the script
auto-detects it via `az repos show --query defaultBranch` and strips the `refs/heads/` prefix. The
script's `az repos pr create` call links the gap work item in the same invocation via
`--work-items` — no separate link-up call, since that flag exists directly on `pr create`. PR
description stays Markdown (ADO PR descriptions render it, unlike work item
`System.Description`) — same content shape as GitHub mode's PR body, minus the `Closes #<N>` line
(Azure DevOps has no equivalent auto-close keyword guaranteed on by default; see the known
limitation below).

**Known limitation** (parallel to the existing "remediation ticket is best-effort" note in Step
9): `--work-items` links the PR to the work item (visible in the work item's Development section
and the PR's Work Items tab) but does **not** by itself close the work item on merge. Whether the
linked work item auto-transitions when the PR completes depends on the org's own branch-policy /
completion settings (`--transition-work-items` on `az repos pr update` at completion time, which is
outside this skill's scope since it only ever creates a draft PR, never completes one). This
mirrors local mode's existing manual-cleanup posture rather than GitHub mode's automatic
`Closes #N` behavior.

### Step 9 — Update POA&M

Unchanged — `**Remediation Ticket:** <PR URL>` is written to the evidence card the same way
regardless of tracker mode.

## Verification plan

No automated test suite exists for this repo's `SKILL.md` instructions (they're LLM instructions,
not executable code — see the existing parallel-family-assessment spec's precedent), and no live
Azure DevOps org is available in this environment to smoke-test the `az` calls end-to-end. The new
bash scripts themselves, however, are ordinary shell scripts and can be syntax-checked directly.
Verification is:

1. **Script syntax check** — `bash -n` every new script; this catches quoting/structural errors
   independent of having live `gh`/`az` credentials.
2. **Structural parallelism check** — the new `azure-devops` branch at each step mirrors the
   `github`/`local` branches: same fields populated, same dedup logic, same completion criteria,
   same failure-handling shape; and the refactored GitHub branches still produce the same
   command/output shape as today's inline calls.
3. **Command accuracy** — every `az boards`/`az repos` flag used was checked against the current
   Microsoft Learn CLI reference during design (not recalled from training data), specifically to
   avoid the trap the reference skill's own "what does NOT work" table documents for adjacent `az`
   commands (e.g. `az boards work-item comment add` doesn't exist; `az rest` without an explicit
   auth header silently redirects instead of erroring).
4. No changes to `test/fixtures/sample-app/` or the control-assessment reasoning (`controls.md`,
   `finding-rules.md`) — this feature only touches tracker plumbing (assess Step 6; remediate Steps
   1, 4, 8), not control interpretation.

## Out of scope

- Decoupling tracker choice from the git remote (e.g. GitHub-hosted code + Azure Boards tracking)
  — explicitly deferred per the design decision above.
- A PAT/token fallback auth chain — the scripts assume an active `gh auth login` / `az login`
  session only.
- Mapping severity to `System.Priority` in addition to tags.
- A configurable work item type — `Issue` is hardcoded, matching the other two modes' lack of a
  configurable issue/label naming scheme today.
- Auto-closing the ADO work item when its PR completes — noted as a known limitation, not solved
  here (parallel to the existing best-effort `Remediation Ticket` link caveat already documented
  for the other two modes).
- A shared cross-skill script location — scripts are intentionally duplicated per skill folder for
  portability, per the design decision above.
