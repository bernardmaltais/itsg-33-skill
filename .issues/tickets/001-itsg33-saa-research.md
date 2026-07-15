---
id: "001"
title: "What does the ITSG-33 SA&A process actually entail?"
label: wayfinder:research
status: closed
parent: MAP.md
blocks: ["002", "003", "004"]
assignee: claude
---

## Question

What is the full ITSG-33 Security Assessment and Authorization (SA&A) process, and what does it mean for a code assessment skill?

Specifically surface:

1. **The control catalogue** — How many controls are there? How are they organized (families, classes)? What is the difference between LOW, MEDIUM, and HIGH profiles in terms of which controls apply and at what stringency?

2. **What "assessable from code" means** — Which control families are technical and could be evaluated by reading a codebase (e.g., AC, AU, IA, SC, SI)? Which are purely process/policy (e.g., AT, PM, PL) and cannot be assessed from a repo at all?

3. **The SA&A lifecycle** — What are the phases (categorization, control selection, implementation, assessment, authorization, monitoring)? Where does a code-level assessment tool fit in?

4. **Evidence cards / artefact conventions** — What does a compliant evidence card look like? What fields are required? How does the existing repo's template map to the official process?

5. **Canadian-specific context** — How does ITSG-33 differ from NIST SP 800-53 in practice? Any Treasury Board or CSE guidance that shapes what an assessment tool must produce?

6. **Existing tooling** — Are there existing open-source or commercial tools that already do ITSG-33 or NIST 800-53 code assessment? What do they produce and where do they fall short?
