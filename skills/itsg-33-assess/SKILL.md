---
name: itsg-33-assess
description: >-
  Assess a local repo against ITSG-33 PBMM controls, producing evidence cards, a
  compliance report, and gap issues for failing controls. Use when the user wants
  an ITSG-33 or PBMM compliance assessment, or asks for a Security Assessment
  Report (SAR) package for this repo.
---

Assess the repo's code and IaC against ITSG-33 PBMM controls, producing evidence cards
and a rolled-up compliance report. Every run is **incremental** — re-assess only controls
whose relevant files changed; reuse cached findings for the rest.

## Branch: Init

**Trigger:** `security/itsg33.yaml` is absent.

1. **Prompt** for system name and system boundary description.
2. **Confirm** security profile — default PBMM; accept override.
3. **Detect** tracker mode from `git remote -v`:

   | Remote contains | `tracker` |
   |---|---|
   | `github.com` | `github` |
   | `dev.azure.com` | `azure-devops` |
   | neither | `local` |
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

### Step 2 — Load control catalogue and role taxonomy

Load [`controls.md`](controls.md) via this context pointer, including its **Common Content
Roles** section. That section is the single source of truth for every role name this skill
knows about — Step 3's classification pass and Step 4b's lookup are both driven from it
directly, so there is nothing else to keep in sync when a new tool or convention needs
support. Completion: all control entries and the role taxonomy (name + description per role)
are loaded and available for Steps 3 and 4.

### Step 3 — Classify tracked files by role

1. Enumerate the repo's tracked files once with `git ls-files`. Matching against tracked
   files rather than a raw filesystem walk means anything `.gitignore` excludes — vendored
   dependencies, build output, `node_modules/`, generated artefacts — never enters the
   candidate set at all.
2. Read the persistent classification cache, `security/file-roles.yaml` (JSON content
   despite the `.yaml` name, same convention `assessment-state.yaml` already uses) — a map
   of `<path>` → `{roles: [...], content_hash: <sha256>}` from the previous run. Absent on a
   repo's first run (cold start): treat as empty.
3. Diff: a tracked file with no cache entry, or whose current content hash doesn't match the
   cached one, needs (re)classification this run. Everything else reuses its cached roles
   untouched — this is what keeps repeat runs cheap.
4. If any paths need classification, dispatch **one classification subagent** (fresh context,
   not per-family) with the full role taxonomy (name + description each, from Step 2) and the
   list of paths needing classification. It assigns each path zero or more role names in a
   single reasoning pass. Multi-label is expected and normal (e.g. `Chart.yaml` is both `iac`
   and `dependency-manifest`).
   - **Content-peek escalation:** for any path the subagent can't confidently resolve from
     path/extension alone, it reads that specific file before finalizing a role. Most paths
     resolve from name alone and are never opened.
   - **Novel roles:** the taxonomy is open-ended. If a file doesn't fit any described role,
     the subagent records a new role name as-is rather than forcing it into an existing
     bucket or dropping it.
   - The subagent writes its results as JSON to a scratch input file
     `security/.assessment-fragments/file-roles.input.json`:
     ```json
     {
       "classifications": {
         "<path>": {"roles": ["<role>", "..."], "content_hash": "<sha256 of current content>"}
       }
     }
     ```
     Then run:
     ```bash
     python3 skills/itsg-33-assess/scripts/merge-file-roles.py \
       security/.assessment-fragments/file-roles.input.json \
       security/file-roles.yaml \
       security/file-roles.yaml
     ```
     If this exits non-zero, its stderr names exactly what is wrong (missing field, invalid
     role, malformed JSON, invalid `content_hash`). Fix the input file and re-run — up to 2
     attempts. If it still fails after 2 attempts, this counts as the "malformed output" case
     in the failure handling below.
5. If no paths need classification (every tracked file already has a current cache entry),
   skip dispatch entirely — there is nothing to merge.

**Failure handling:** mirrors Step 4's family-subagent pattern. If the classification
subagent errors or exhausts its 2 `merge-file-roles.py` retry attempts without a clean exit,
retry the subagent once. If the retry also fails, abort the entire run: report why, leave
`security/file-roles.yaml` and `security/assessment-state.yaml` untouched, and leave
`security/.assessment-fragments/` in place for debugging. Do not proceed to Step 4.

Completion: `security/file-roles.yaml` has a current entry (matching content hash) for every
tracked file — reused from cache or freshly classified this run.

### Step 4 — Dispatch family subagents

Partition `controls.md` by control family prefix: **AC, AU, IA, SC, CM, SI, SA, CP, RA**. In a
single message, dispatch one subagent per family (Task/Agent tool, parallel calls) — every
family gets a subagent every run, even if none of its controls changed since the last run.

Each subagent's dispatch prompt must include:
- The active `profile`, `system_name`, `system_boundary`, and tracker mode (from Step 1)
- A pointer to `security/file-roles.yaml` (the role classification cache from Step 3)
- A pointer to `controls.md`, with an instruction to process only entries whose control ID
  starts with its assigned family prefix
- A pointer to `evidence-card.md` (the template to use when writing evidence cards)
- A pointer to `finding-rules.md` (the rules for weighing Pass/Fail/Not Assessable signals in Step 4c)
- The subagent contract below (steps 4a-4e)

**Subagent contract (per family)**

For each control in the assigned family, in order:

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
cached control either, since its evidence card is not rewritten — but `write-fragment.py` still
requires every field to be present, so do not omit them. Use a short placeholder string such as
`"(cached — see evidence card)"` for the three string fields, and a placeholder list such as
`["(cached)"]` for `evidence_artefacts` (any list is accepted; an empty list `[]` also works).
Skip to next control.

**4b. Read relevant files**
Look up this control's **File patterns (roles)** line in `controls.md`. Read
`security/file-roles.yaml` and take every path whose `roles` list intersects this control's
role names. If at least one path matches, read the matched files and proceed to 4c. There is
no separate fallback step here — Step 3's content-peek escalation already resolved every
ambiguous file proactively during classification, for every control, not reactively for a
pre-selected handful of domains after a glob came up empty.

If no path in `security/file-roles.yaml` carries any of this control's roles → finding is
**Not Assessable**; record `reason: no files classified with this control's roles`; skip to 4d.

**4c. Reason**
Read the matched files. Apply the control's **Pass signals** and **Fail signals** from
`controls.md`, weighing them per the rules in [`finding-rules.md`](finding-rules.md) (load via
this context pointer).

Derive:
- `finding`: Pass / Fail / Not Assessable
- `severity`: P1 / P2 / P3, written only to the evidence card's `Severity` field (not part
  of write-fragment.py's schema); Steps 6–8 read it back from there
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
      "files_read": {"<relative path>": "<sha256>"},
      "cached": true
    }
  }
}
```
(Omit `"cached"` entirely for a control that was freshly assessed this run — only set it to
`true` for a cache hit per Step 4a.)

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

1. Run:
   ```bash
   python3 skills/itsg-33-assess/scripts/merge-state.py \
     security/.assessment-fragments \
     security/assessment-state.yaml \
     security/assessment-state.yaml \
     <profile>
   ```
   (`<profile>` is the profile from Step 1, e.g. `PBMM`.) This script is the sole writer of
   `security/assessment-state.yaml`, including the PBMM plausibility check (a synthetic
   `PLAUSIBILITY-WARNING` control appended when every SC and every IA control comes back Not
   Assessable) — nothing is hand-edited into this file afterward. For any control a fragment
   marks `"cached": true`, it
   uses the `finding`/`confidence`/`files_read` already stored in the pre-run
   `security/assessment-state.yaml` verbatim, discarding whatever the fragment wrote for those
   fields. For every other control, it takes `finding`/`confidence`/`files_read` directly from
   the fragment.

   If this exits non-zero, its stderr names exactly what is wrong: no fragment files found, a
   control present in more than one fragment, a control (cached or not) missing a required
   field, a control marked cached with no prior entry to carry forward, or a fragment/existing-
   state file that isn't valid JSON. Treat this as a "malformed output" case
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

### Step 6 — Create gap issues

For each **Fail** finding, create a gap issue only if no open gap already exists for
that control. Get `<P1|P2|P3>` for each control from its evidence card's `**Severity:**`
line (see Step 4c) — it is not present in `security/assessment-state.yaml`.

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

### Step 7 — Regenerate assessment report (Markdown)

Write/overwrite `security/assessment-report.md` following the structure at
[`report-template.md`](report-template.md) (load via this context pointer). The POA&M's
`Severity` column comes from each Fail control's evidence card `**Severity:**` line (Step 4c),
same source as Step 6's gap-issue tags. Populate **Detected Technology Without a Mapped
Control** from `security/file-roles.yaml` (Step 3): any role present there that no control's
File patterns (roles) line in `controls.md` references. This is informational only — it never
feeds Pass/Fail logic. Omit the section if there are none.

Completion: file written; POA&M includes one row per Fail finding; evidence cards index
links to every file in `security/evidence/`.

### Step 8 — Regenerate assessment report (HTML)

Write/overwrite `security/assessment-report.html` as a **self-contained** file (inline CSS,
no external resources), using the same structure as [`report-template.md`](report-template.md).
Include:

- Summary dashboard as stat tiles (Pass count in green, Fail in red, Not Assessable in grey)
- Control family breakdown as a simple table
- Top 3 gaps highlighted
- POA&M table with sortable columns (use plain `<table>` with `<th>` — no JS required)
- Detected Technology Without a Mapped Control table (omit if empty), same data as Step 7
- Evidence cards index as a linked list (links to the `.md` files)

Completion: `security/assessment-report.html` exists; opening it in a browser renders
correctly with no external requests.
