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

### Step 4 — Assess each control

For each control in `controls.md`, in order:

**4a. Cache check**
Read `security/assessment-state.yaml`. For each file listed under this control's
`files_read`, hash the current content and compare to the stored hash. If all hashes
match → mark this control `cached`, carry the prior finding forward, skip to next control.

**4b. Read relevant files**
Glob the control's **File patterns** against the repo. If no files match any pattern →
finding is **Not Assessable**; record `reason: no matching files`; skip to 4d.

**4c. Reason**
Read the matched files. Apply the control's **Pass signals** and **Fail signals** from
`controls.md`. Derive:
- `finding`: Pass / Fail / Not Assessable
- `confidence`: plain-English note explaining what was found or not found
- `risk_summary`: one-to-two sentence attacker-perspective statement (from controls.md risk context)
- `implementation_approach`: narrative of how the system implements (or fails to implement) the control, citing specific files and config constructs
- `evidence_artefacts`: bulleted list of relative file paths with a note on what each demonstrates
- `client_responsibility`: what application teams must do to maintain their side of this control
- `files_read`: map of `<relative path>` → SHA-256 of file content (used for cache check in 4a and stored in Step 5)

**4d. Record finding**
Completion criterion: every control in `controls.md` has a finding (Pass / Fail /
Not Assessable / cached) and a confidence note.

---
*(End of per-control loop. The following check runs once after all controls are assessed.)*

**Plausibility check**
If `profile: PBMM` and **all** of the following returned Not Assessable:
- Every SC (System and Communications Protection) control
- Every IA (Identification and Authentication) control

→ append a synthetic finding `PLAUSIBILITY-WARNING`:
  - Finding: Not Assessable
  - Confidence: "PBMM declared but no encryption, auth, or network config was found. Verify the repo contains the relevant IaC or manifests, or that the system boundary is correctly scoped."

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

### Step 6 — Write evidence cards

For each control with a finding (including cached), write/update
`security/evidence/<control-id>.md` using the template at [`evidence-card.md`](evidence-card.md)
(load via this context pointer). Populate all fields from the finding recorded in Step 4.
Completion: one `.md` file per assessed control exists in `security/evidence/`.

### Step 7 — Create gap issues

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

### Step 8 — Regenerate assessment report (Markdown)

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

### Step 9 — Regenerate assessment report (HTML)

Write/overwrite `security/assessment-report.html` as a **self-contained** file (inline CSS,
no external resources). Mirror the structure from Step 8. Include:

- Summary dashboard as stat tiles (Pass count in green, Fail in red, Not Assessable in grey)
- Control family breakdown as a simple table
- Top 3 gaps highlighted
- POA&M table with sortable columns (use plain `<table>` with `<th>` — no JS required)
- Evidence cards index as a linked list (links to the `.md` files)

Completion: `security/assessment-report.html` exists; opening it in a browser renders
correctly with no external requests.
