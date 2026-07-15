# Project: ITSG-33 Platform Compliance Documentation

This repo tracks ITSG-33 control compliance for the Aurora Kubernetes Platform via evidence cards, a system boundary statement, IaC mappings, and a gap tracker. See `readme.md` for human-facing orientation.

## Standard Operating Procedures

When creating, updating, or reviewing compliance documentation in this repo, you MUST follow these rules:

### 1. Adhere to the evidence card template

Every evidence card must match the structure of `evidenceCard/template-evidenceCard.md`. Pay particular attention to the **Inherited Evidence** section and use the `[Inherited]` flag whenever a control is fulfilled by the Landing Zone (LZ) or Cloud Service Provider (CSP) rather than the platform.

### 2. Keep the system boundary statement current

Always review `system_boundary_statement.md` before making substantive changes. If your analysis — or the user's request — reveals a new system boundary, dependency, or a shift in responsibility (e.g., from platform to enterprise, or from platform to CSP), propose updates to `system_boundary_statement.md` as part of the same change.

### 3. Keep IaC mappings in sync with evidence

If you create a new evidence card or add a mapping to a specific IaC artifact (e.g., a `.tf` file, a Kubernetes manifest, or a Helm chart), add a corresponding row to `iac_mappings.md` in the same change.

### 4. Track gaps explicitly — never silently ignore them

If during review or creation you identify a security red flag, a missing control, or an evidence gap (where a control cannot be fully satisfied), record it in `other_docs/potential_gaps.md`. Incomplete compliance areas must be visible, not hidden.

## Reviewer subagents

Three role-based reviewers are defined in `.claude/agents/`:

- `security-architect` — ITSG-33 control traceability and IaC-to-control mapping
- `platform-devx-reviewer` — developer-experience and operational-usability impact
- `cyber-independent-expert` — impartial review against Canadian federal cybersecurity standards

Dispatch them via the Agent tool when the user asks for a review, a second opinion, or a multi-angle evaluation. They can be run in parallel on the same artifact to get three independent perspectives.
