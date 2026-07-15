---
label: wayfinder:map
status: open
tracker: https://github.com/bernardmaltais/itsg-33-skill/issues/1
note: Issues are now tracked on GitHub — this file is superseded.
---

# Map: ITSG-33 Code Assessment Skill

**Tracker:** https://github.com/bernardmaltais/itsg-33-skill/issues/1

Issues migrated to GitHub:
- Map: https://github.com/bernardmaltais/itsg-33-skill/issues/1
- Ticket 001 (CLOSED): https://github.com/bernardmaltais/itsg-33-skill/issues/2
- Ticket 002: https://github.com/bernardmaltais/itsg-33-skill/issues/3
- Ticket 003: https://github.com/bernardmaltais/itsg-33-skill/issues/4
- Ticket 004: https://github.com/bernardmaltais/itsg-33-skill/issues/5

# Map: ITSG-33 Code Assessment Skill

## Destination

A Claude Code skill (`SKILL.md`) that a developer or security assessor can invoke against any local repo to: (1) assess the code against applicable ITSG-33 controls, (2) produce a human-readable compliance report (phase 1), and (3) optionally drive a remediation workflow that proposes concrete fixes with pre/post test validation (phase 2).

## Notes

- Domain: Canadian federal cybersecurity — ITSG-33 (mirrors NIST SP 800-53), SA&A process
- Skills to consult each session: `/grilling`, `/domain-modeling`, `/deep-research`
- The repo's `reference/instructions.md` describes compliance documentation for the Aurora Kubernetes Platform — treat as domain context, not the target of this skill
- User is not yet familiar with the full ITSG-33 SA&A process — research must precede design decisions
- Target users: developers checking their own service before SA&A, and/or security assessors auditing a platform

## Decisions so far

- [What does the ITSG-33 SA&A process actually entail?](tickets/001-itsg33-saa-research.md) — 8 technical families are code-assessable (AC/AU/CM/IA/SC/SI/SA/CP); 10 are process-only. Output should be evidence cards (one per control). Profile (LOW/MEDIUM/HIGH or PBMM) must be user-declared. Phase 1 = evidence cards; Phase 2 = gap remediation with pre/post tests. The LLM-narrative-to-SA&A-evidence translation is the unique value no existing tool provides. Full findings in [001-resolution.md](tickets/001-resolution.md).

## Not yet specified

- What subset of ITSG-33 controls are code-assessable vs. process/policy-only (can't be read from a repo)
- How the skill identifies which security profile (LOW/MEDIUM/HIGH) applies — user-declared vs. inferred
- Where control knowledge lives — embedded catalogue, reference to existing repo artifacts, or both
- What the remediation workflow looks like step-by-step (phase 2)
- How pre/post test validation is structured — what counts as a "test baseline"
- Output format for the compliance report (evidence-card style, gap tracker, narrative, structured JSON)
- Whether the skill generates diffs/PRs or only proposes changes in prose

## Out of scope

<!-- nothing ruled out yet -->
