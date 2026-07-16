# Dynamic file-role classification, replacing static glob patterns in controls.md

**Status:** Approved for planning
**Date:** 2026-07-16
**Supersedes:** The "hybrid" decision in
[2026-07-16-controls-pattern-generalization-design.md](2026-07-16-controls-pattern-generalization-design.md),
which explicitly rejected fully content-based matching in favor of shared glob families
(`{IaC}`, `{CI/CD}`, `{App source}`) plus a two-layer fallback. That design shipped and was
then audited control-by-control (see Background) — the audit found the same enumeration
problem recurring in nearly every family, plus a structural gap (three families with no
content-marker fallback at all) and a self-inflicted extension collision. This spec replaces
the glob-family mechanism entirely rather than patching it again.

## Background

Following the prior design's rollout, an audit of the newly-widened `{App source}` list
surfaced two things: real gaps beyond language coverage (JSX/TSX/mjs/cjs missing from an
otherwise-"complete" JS/TS entry — a bigger practical miss than any exotic language), and a
`.pp` collision introduced by the widening itself (Pascal vs. Puppet manifests routed into
the wrong control family). Auditing the other 13 families turned up the same pattern
repeatedly:

- `{Dependency manifest}` has `package.json` but not `package-lock.json`/`yarn.lock`/
  `pnpm-lock.yaml` — undermining CM-8's own stated Pass signal ("lockfiles exist") for the
  most common ecosystem. Also missing `pyproject.toml`/`poetry.lock`, `build.gradle.kts`,
  `Cargo.toml`, NuGet's `packages.lock.json`, and Helm's actual `Chart.lock`.
- `{CI/CD}` only matches `.github/workflows/*.yaml` — not `.yml`, an even split by
  convention across real repos.
- `{IaC}` misses `.tfvars`, `.tf.json`, generic `.hcl`, and CloudFormation templates not
  named `*.template.yaml` or under a `cloudformation/` directory.
- The content-marker fallback (SKILL.md Step 4b, layer 2) only covers 6 of the families that
  need it (Service mesh, Admission controller, Cert management, Observability, Image
  signing, IdP) — `{Log shipping}`, `{Reverse proxy}`, and `{Time sync}` have no content
  escape hatch at all, despite being just as identifiable-by-content-not-filename (e.g.
  chrony/NTP are traditionally configured via `/etc/chrony.conf`, not YAML — not matched
  today in any form).
- Beyond the 14 shared families, every individual control's own inline literal patterns
  (`**/rbac*.yaml`, `**/session*.yaml`, `**/audit*.yaml`, ...) have the identical problem at
  smaller scale — each is its own small enumeration that will eventually miss a filename
  convention it didn't anticipate.

The pattern is consistent: any static enumeration of "files that mean X" drifts behind the
real world, and the fix each time is the same shape (widen the list, add a fallback). This
spec generalizes the fix instead of repeating it: replace every glob (shared family or
per-control literal) with a named, described **role**, and classify the repo's tracked files
against that role taxonomy dynamically, per run.

## Decision

## Part A — Role taxonomy replaces `controls.md` patterns

`controls.md`'s "Common Pattern Families" section is renamed **Common Content Roles** and
changes from glob-set definitions to short semantic descriptions, e.g.:

```
- **`iac`** — infrastructure declared and provisioned as code (Terraform, Bicep,
  CloudFormation, Pulumi, Ansible playbooks, ...), identified by convention or content,
  not by a fixed extension list.
- **`app-source`** — application/service source code in any programming language.
- **`rbac-definition`** — Kubernetes RBAC objects: Roles, ClusterRoles, RoleBindings,
  ClusterRoleBindings, service account definitions.
- **`session-config`** — session/token lifecycle settings (timeout, revocation, refresh
  expiry), wherever configured.
```

This taxonomy covers **every** concept currently expressed as a pattern anywhere in
`controls.md` — both the 14 shared family tokens and every control-specific inline literal
(`**/rbac*.yaml`, `**/session*.yaml`, `**/audit*.yaml`, `**/headers*.yaml`, etc.). Building
the full deduplicated list (walking every control's current `File patterns` line, merging
equivalent concepts, writing one description each) is the first implementation task, not
something this spec enumerates exhaustively — expect roughly 45-55 roles once duplicates
across controls collapse (e.g. today's `**/rbac*.yaml` is reused verbatim by AC-2, AC-3,
AC-6, IA-4, and CM-5, and becomes one `rbac-definition` role).

Every control's `File patterns` line becomes a flat list of role names:

```
### AC-2 — Account Management
**File patterns (roles):** `iac`, `rbac-definition`, `service-account`, `helm-values`
```

The "How to read an entry" section's note about `{Name}` token expansion, and the note
about not adding a literal pattern redundant with a family token, are both deleted — there
are no globs left for either to apply to.

## Part B — Classification mechanics and incremental caching

`SKILL.md` Step 3 (Fingerprint tech stack) is replaced by a classification pass:

1. Enumerate tracked files via `git ls-files` (the tracked-files-only fix from the prior
   session stays — vendored/build/generated content still never enters the candidate set).
2. Read the persistent classification cache, `security/file-roles.yaml` — a map of
   `<path>` → `{roles: [...], content_hash: <sha256>}` from the previous run.
3. Diff: a tracked file with no cache entry, or whose content hash changed, needs
   (re)classification this run. Everything else reuses its cached roles untouched. This is
   what keeps "no more free glob pass" affordable on repeat runs — the same incremental
   principle Step 4a already applies to per-control findings, applied here to file-role
   assignment instead.
4. Dispatch **one classification subagent** (fresh context, not per-family) with the full
   role taxonomy (name + description each) and the list of paths needing classification. It
   assigns each path zero or more role names in a single reasoning pass. Multi-label is
   expected and normal — `Chart.yaml` is legitimately both `iac` and `dependency-manifest`.
5. **Content-peek escalation**: for any path the subagent can't confidently resolve from
   path/extension alone, it reads that specific file before finalizing a role. This
   generalizes today's content-marker fallback (hardcoded to 6 domains) into something every
   ambiguous file gets, not just the ones in a pre-selected list — and resolves the `.pp`
   collision by construction: a Puppet manifest and a Pascal unit look nothing alike once
   actually read. Most paths resolve from name alone and are never opened at all, so cost
   stays bounded to the genuinely ambiguous minority.
6. **Novel roles**: the taxonomy is open-ended, not a closed enum. If the subagent finds a
   file that doesn't fit any described role (e.g. a `.sops.yaml` it labels
   `secrets-encryption-at-rest`), that's recorded as-is rather than forced into an existing
   bucket or dropped.
7. Output is validated and merged into `security/file-roles.yaml` by a small script (same
   shape as `write-fragment.py`/`merge-state.py`: schema-checked, single writer, rejects
   malformed output) — new cache entries for reclassified paths, existing entries for
   everything untouched.

`SKILL.md` Step 4b's contract shrinks from "glob + two fallback layers" to a lookup: each
family subagent reads `security/file-roles.yaml` and takes every path whose `roles` list
intersects its control's referenced role names. The cross-family fallback and content-marker
fallback layers are deleted — both are subsumed by step 5 above, which runs proactively for
every ambiguous file during classification rather than reactively for a handful of domains
after a control's glob already came up empty.

## Part C — Reporting and failure handling

Unmapped/novel roles surface in `security/assessment-report.md` (and the HTML equivalent) as
a new **"Detected Technology Without a Mapped Control"** section — role name, file count,
example paths. This is informational only; it never feeds Pass/Fail logic. It's the
mechanism for someone reading the report to notice "this system uses tool X and nothing in
ITSG-33's current control set looks for it" — same spirit as the existing synthetic
`PLAUSIBILITY-WARNING` control, but as a report section, since these aren't controls.

Classification-subagent failure handling mirrors Step 4's existing family-subagent pattern:
malformed/invalid output or an error gets one retry; if the retry also fails, abort the run,
leave `security/file-roles.yaml` and `security/assessment-state.yaml` untouched, and report
why — the same abort-safety guarantee the skill already gives for family subagents.

**Cold start:** a repo's first run has no cache, so every tracked file is classified fresh —
the same cost profile the skill already has today when every family subagent runs fresh on
first use.

**Files touched:**
- `controls.md` — "Common Pattern Families" → "Common Content Roles"; every control's `File
  patterns` line rewritten to a role-name list; the token-expansion and redundant-literal
  notes deleted.
- `SKILL.md` Step 2/3 — rewritten from "load glob families, glob each against the repo" to
  "load the role taxonomy, run/read the classification pass, diff against the cache."
- `SKILL.md` Step 4b — rewritten from "glob + two fallback layers" to "look up files tagged
  with this control's roles in `security/file-roles.yaml`."
- New script: validates the classification subagent's output and merges it into
  `security/file-roles.yaml` (mirrors `write-fragment.py`'s contract).
- `report-template.md` — gains the unmapped-roles section.

## Verification plan

No automated test suite covers `SKILL.md`/`controls.md` prose (LLM instructions, not
executable code — same posture as every prior design spec in this repo). Verification is:

1. **Consistency check** — grep `controls.md` after the edit to confirm no glob pattern
   (`**/*.`, literal filenames, family tokens) remains anywhere outside the merge/write
   script's own code; every `File patterns` line is a role-name list.
2. **Taxonomy completeness check** — cross-reference the built role taxonomy against every
   control's *current* (pre-edit) `File patterns` line to confirm every existing concept has
   a home; nothing silently drops a control's assessment surface in the rewrite.
3. **Fixture dry run** — run `itsg-33-assess` against the existing fixture repo(s) before and
   after the edit; classification + role lookup should produce the same file sets the old
   globs did for the fixture's known stack (Terraform/K8s/GitHub Actions), so findings should
   be unchanged.
4. **New-stack smoke test** — construct or extend a fixture with at least one file whose role
   is only resolvable by content (e.g. a Puppet `.pp` manifest, or a CloudFormation template
   not named `*.template.yaml`) and confirm classification assigns the correct role.
5. **Schema check** — confirm the new merge script rejects a malformed classification output
   the same way `write-fragment.py` does today (missing role, invalid path, bad hash),
   matching this repo's existing convention of explicit stderr on bad input.

## Out of scope

- Enumerating the full ~45-55 role taxonomy in this document — that's the first
  implementation task, done against the actual current `controls.md` content.
- Migrating `security/assessment-state.yaml`'s existing cache format — it's unaffected;
  `security/file-roles.yaml` is a new, separate cache file.
- Automatically inferring new controls from unmapped roles — the report section is purely
  informational; adding a control for a newly-surfaced role remains a human decision.
