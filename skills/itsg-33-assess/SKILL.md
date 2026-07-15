---
name: itsg-33-assess
description: >-
  Assess a local repo against ITSG-33 PBMM controls and produce evidence cards,
  a compliance report, and gap issues. Use when the user invokes itsg-33-assess,
  wants an ITSG-33 compliance assessment, asks about PBMM controls, or wants to
  generate evidence cards or a Security Assessment Report (SAR) package.
---

Assess the repo's code and IaC against ITSG-33 PBMM controls, producing evidence cards
and a rolled-up compliance report. Every run is **incremental** — re-assess only controls
whose relevant files changed; reuse cached findings for the rest.

## Branch: Init

**Trigger:** `security/itsg33.yaml` is absent.

1. **Prompt** for system name and system boundary description.
2. **Confirm** security profile — default PBMM; accept override.
3. **Detect** tracker mode: GitHub remote present → `github`; absent → `local`.
4. **Write** `security/itsg33.yaml`:
   ```yaml
   profile: PBMM
   system_name: <value>
   system_boundary: <value>
   tracker: <github | local>
   ```
   Completion: file exists and all four fields are populated.
5. **Create** folder structure:
   - `security/evidence/` — one `.md` per assessed control
   - `security/gaps/` — local gap files (used when `tracker: local`)
   Completion: both directories exist.
6. Continue directly into the **Assess branch** — no separate invocation needed.

---

## Branch: Assess

**Trigger:** Every run (including immediately after Init).

### Step 1 — Read config

Read `security/itsg33.yaml`. Accept `--profile <value>` argument as a run-time override
of `profile`. Completion: active profile and tracker mode are known.

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

Load [`controls.md`](controls.md) via this context pointer. Completion: all control entries are loaded and available for Step 4.

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
- The subagent contract below (steps 4a-4e)

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

**4e. Write evidence card**
For each control with a finding (including cached, per 4a's no-rewrite rule), write/update
`security/evidence/<control-id>.md` using the template at [`evidence-card.md`](evidence-card.md)
(load via this context pointer). Populate all fields from the finding recorded in 4c/4d.
Completion: one `.md` file per control in the assigned family exists in `security/evidence/`.

*(End of per-control loop.)*

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

**Failure handling:** If a subagent errors, exhausts its 2 write-fragment.py
retry attempts without a clean exit, or produces a fragment missing/duplicating a control, the
orchestrator retries that one family's subagent once. If the
retry also fails, abort the entire run: report which family failed and why, leave
`security/assessment-state.yaml` and `security/evidence/` untouched, and leave
`security/.assessment-fragments/` in place for debugging. Do not proceed to Step 5.

### Step 5 — Merge state

Once all 9 fragments exist in `security/.assessment-fragments/`:

1. Read and JSON-parse all fragments. Confirm every control in `controls.md` appears in exactly one
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

### Step 6 — Create gap issues

For each **Fail** finding, create a gap issue only if no open gap already exists for
that control.

**GitHub mode** (`tracker: github`):
- Create a GitHub Issue with:
  - Title: `[itsg-33:gap] <Control ID> — <Control Name>`
  - Labels: `itsg-33:gap`, `P1` / `P2` / `P3` (from control's severity in `controls.md`)
  - Body: control ID, finding, confidence note, recommended action, link to evidence card
- Skip if an open issue with the same title already exists.

**Local mode** (`tracker: local`):
- Write `security/gaps/<control-id>.md` with the same fields.
- Skip if the file already exists.

Completion: every Fail finding has a gap issue or gap file; no duplicates created.

### Step 7 — Regenerate assessment report (Markdown)

Write/overwrite `security/assessment-report.md`. Structure:

```
# ITSG-33 Assessment Report — <system_name>

**Profile:** <profile>  **Date:** <ISO date>  **System boundary:** <system_boundary>

## Summary Dashboard

| Metric | Value |
|--------|-------|
| Controls assessed | <n> |
| Pass | <n> |
| Fail | <n> |
| Not Assessable | <n> |
| Open gaps | <n> |

## Control Family Breakdown

<table: family | pass | fail | not assessable>

## Top 3 Highest-Priority Gaps

<ordered list: P1 first, then P2, then P3; control ID, confidence, gap issue link>

## POA&M

| Control ID | Finding | Confidence | Severity | Recommended Action | Owner | Target Date | Remediation Ticket |
|------------|---------|------------|----------|--------------------|-------|-------------|--------------------|
| ...        | Fail    | ...        | P1       | ...                |       |             |                    |

## Evidence Cards Index

<bulleted list of links to security/evidence/<control-id>.md>
```

Completion: file written; POA&M includes one row per Fail finding; evidence cards index
links to every file in `security/evidence/`.

### Step 8 — Regenerate assessment report (HTML)

Write/overwrite `security/assessment-report.html` as a **self-contained** file (inline CSS,
no external resources). Mirror the structure from Step 7. Include:

- Summary dashboard as stat tiles (Pass count in green, Fail in red, Not Assessable in grey)
- Control family breakdown as a simple table
- Top 3 gaps highlighted
- POA&M table with sortable columns (use plain `<table>` with `<th>` — no JS required)
- Evidence cards index as a linked list (links to the `.md` files)

Completion: `security/assessment-report.html` exists; opening it in a browser renders
correctly with no external requests.
