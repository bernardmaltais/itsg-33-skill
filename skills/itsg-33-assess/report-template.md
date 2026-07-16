# Assessment Report Template

Canonical structure for `security/assessment-report.md` (Step 7) and
`security/assessment-report.html` (Step 8 — same structure, rendered as self-contained HTML).

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

## Detected Technology Without a Mapped Control

Informational only — never feeds Pass/Fail logic. Lists any role recorded in
`security/file-roles.yaml` (Step 3) that isn't referenced by any control's File patterns
(roles) line in `controls.md`, i.e. a novel role the classification subagent assigned
because no described role fit. Omit this section entirely if there are none.

| Role | File count | Example paths |
|------|-----------|----------------|
| ...  | ...       | ...            |

## Evidence Cards Index

<bulleted list of links to security/evidence/<control-id>.md>
```
