# ITSG-33 SA&A Lifecycle Reference

**Source:** Canadian Centre for Cyber Security (CCCS) — cyber.gc.ca  
**Document:** ITSG-33 Annex 2 — Information System Security Risk Management Activities (ISSIP)  
**Fetched:** 2026-07-15

---

## Overview

The ITSG-33 SA&A process follows the **Information System Security Implementation Process (ISSIP)** — a 9-phase lifecycle aligned to the system development lifecycle (SDLC), followed by Operations & Maintenance and Disposal.

---

## Phases and Outputs

| Phase | Key Activities | Outputs |
|-------|---------------|---------|
| **1. Stakeholder Engagement** | Identify and engage security stakeholders | List of security stakeholders |
| **2. Concept** | Select domain security control profiles/TA reports; determine system security category; identify and approve initial security assurance requirements | Security control profile(s); Information system security categorization report; Approved initial security assurance requirements |
| **3. Planning** | Integrate ISSIP activities into project plan; obtain plan approval | Approved project plan with ISSIP activities |
| **4. Requirements Analysis** | Define business needs for security; tailor security controls; assess tailoring; approve controls | Business needs for security; System security controls; Assessment statement; Approved security controls |
| **5. High-Level Design** | Incorporate security controls into design (including TRA activities); assess and approve design | High-level design specs with security controls; TRA results; Assessment statement; Approved design |
| **6. Detailed Design** | Incorporate security mechanisms; conduct TRA activities; assess and approve design | Detailed design specs; Final security controls; Updated assurance requirements; Assessment statement |
| **7. Development** | Establish secure development environment; develop/test security solutions; assess both | Dev environment documentation; Implementation representation; Test plans/results; Operational and installation procedures; Assessment statements |
| **8. Integration and Testing** | Install security in test environment; conduct integration security testing; assess results; approve production installation | Integration test plans/results; Assessment statement; Approval to proceed |
| **9. Installation** | Install/verify security in production; assess verification; conduct residual risk assessment; prepare operations plan security provisions; assemble authorization package; authorize operations | Security installation verification results; Residual risk assessment; Security provisions for operations plan; Authorization package; **Authority to Operate (ATO)** |
| **Operations & Maintenance** | Continuous monitoring; maintain authorization; change management | Ongoing evidence; POA&M updates |
| **Disposal** | Secure asset disposal; final signoff | Disposal records |

---

## Where a Code Assessment Skill Fits

A code/IaC assessment skill is most valuable at:

- **Phase 7 (Development):** Validate that implemented code/IaC satisfies the security controls approved in Phase 4. Generate evidence artefacts for the authorization package.
- **Phase 8 (Integration and Testing):** Run as part of integration testing to confirm security mechanisms are operating correctly.
- **Phase 9 (Installation):** Verify production configuration matches approved design before ATO.
- **Operations & Maintenance (continuous):** Run on each commit/PR to detect drift from the authorized baseline — feeding CA-7 (Continuous Monitoring).

---

## Key Concepts

### Security Assurance Levels (SAL)
- **SAL1** — Low assurance (not typically used for GC systems)
- **SAL2** — Medium assurance (most PBMM controls)
- **SAL3** — High assurance (boundary/critical controls in PBMM Profile 1)

### Priority Tiers (P1/P2/P3)
Controls in the selected profile are tiered by implementation priority:
- **P1** — Implement first (foundational controls)
- **P2** — Implement second
- **P3** — Implement last (or if resources allow)

### Responsible Parties
Each control is assigned to one or more responsible parties:
- IT Security
- IT Operations
- IT Projects
- Physical/Personnel Security
- Learning Center

### Threat Risk Assessment (TRA)
A TRA is conducted alongside the ISSIP (Phases 5–6) to identify threats, vulnerabilities, and residual risks. The TRA informs control tailoring and supplementation.

### Plan of Action and Milestones (POA&M)
Tracks security gaps (controls not yet fully implemented) with planned remediation dates. Updated throughout Operations & Maintenance.

---

## Authorization Package Components

Assembled in Phase 9 and presented to the Designated Authority (DA) for ATO:

1. System Security Plan (SSP) — PL-2
2. Security Assessment Report (SAR) — CA-2
3. Plan of Action and Milestones (POA&M) — CA-5
4. Residual Risk Assessment
5. Evidence artefacts (evidence cards, test results, IaC mappings)

---

## Sources

- https://www.cyber.gc.ca/en/guidance/annex-2-information-system-security-risk-management-activities-itsg-33
- https://www.cyber.gc.ca/en/guidance/it-security-risk-management-lifecycle-approach-itsg-33
