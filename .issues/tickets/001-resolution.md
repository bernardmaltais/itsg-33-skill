# Research Findings: What does the ITSG-33 SA&A process actually entail?

## Reference files (authoritative, sourced from cyber.gc.ca)

- [`reference/itsg-33-control-catalogue.md`](../reference/itsg-33-control-catalogue.md) — full control list, all 18 families, Canadian-specific controls
- [`reference/itsg-33-saa-lifecycle.md`](../reference/itsg-33-saa-lifecycle.md) — 9-phase ISSIP lifecycle, outputs per phase, authorization package components  
- [`reference/itsg-33-code-assessable-controls.md`](../reference/itsg-33-code-assessable-controls.md) — per-family analysis of what can vs. cannot be assessed from code

**Ticket:** 001  
**Status:** RESOLVED  
**Resolved by:** claude — authoritative data fetched directly from cyber.gc.ca (Annex 3A and Annex 2 web pages); SA&A lifecycle from Annex 2. Full catalogue and lifecycle now stored in `reference/` folder.

---

## 1. The Control Catalogue

**Source document:** ITSG-33, "IT Security Risk Management: A Lifecycle Approach" — published by the Communications Security Establishment (CSE) Canada. Annex 3 contains the Security Control Catalogue.

ITSG-33 Annex 3 organizes controls into **18 families**, directly mirroring NIST SP 800-53 Rev 4:

| ID | Family |
|----|--------|
| AC | Access Control |
| AT | Awareness and Training |
| AU | Audit and Accountability |
| CA | Security Assessment and Authorization |
| CM | Configuration Management |
| CP | Contingency Planning |
| IA | Identification and Authentication |
| IR | Incident Response |
| MA | Maintenance |
| MP | Media Protection |
| PE | Physical and Environmental Protection |
| PL | Planning |
| PM | Program Management |
| PS | Personnel Security |
| RA | Risk Assessment |
| SA | System and Services Acquisition |
| SC | System and Communications Protection |
| SI | System and Information Integrity |

Total controls: approximately **330 base controls + enhancements** in the full catalogue, though many are optional or profile-dependent.

**Security Profiles (LOW / MEDIUM / HIGH):**  
Based on the sensitivity of information handled (PBMM = Protected B, Medium integrity, Medium availability is the common Canadian cloud baseline):

- **LOW profile** — applies to systems handling public/unclassified info. Smallest control set, minimal enhancements selected.
- **MEDIUM profile** — applies to Protected A/B systems. A significantly larger set including most technical controls and some enhanced variants (e.g., AC-2(1), IA-2(1)). This is the dominant profile for GC cloud workloads.
- **HIGH profile** — Classified/sensitive systems. Full control set, most enhancements required, often includes compensating controls.

The profile determines: (a) which controls are **required** vs. optional, and (b) which **enhancements** (parenthetical variants like AC-2(1)) are in scope.

---

## 2. Code-Assessable vs. Process/Policy-Only Controls

### Technical families — assessable from code/IaC/config:

| Family | What code reveals |
|--------|------------------|
| **AC** — Access Control | RBAC roles, policies, permission scopes, network policies, API auth |
| **AU** — Audit & Accountability | Log configuration, retention settings, audit event types |
| **CM** — Configuration Management | Baseline configs, hardening, IaC drift, image pinning |
| **IA** — Identification & Authentication | Auth mechanisms, MFA enforcement, credential storage, service accounts |
| **SC** — System & Communications Protection | TLS config, encryption at rest/transit, network segmentation, secrets management |
| **SI** — System & Information Integrity | Vulnerability scanning config, dependency pinning, integrity checks, input validation |
| **SA** (partial) | Dependency management, SBOM, third-party code vetting practices visible in CI |
| **CP** (partial) | Backup/recovery config, replication settings |

### Process/policy-only families — cannot be assessed from code:

| Family | Why code can't assess it |
|--------|--------------------------|
| **AT** — Awareness & Training | Training records are HR/LMS artifacts, not in repos |
| **PL** — Planning | System Security Plan is a document, not code |
| **PM** — Program Management | Organizational policies, governance structures |
| **PS** — Personnel Security | Background checks, personnel agreements |
| **PE** — Physical & Environmental | Physical access controls, data centre posture |
| **MA** — Maintenance | Maintenance procedures, physical access logs |
| **MP** — Media Protection | Physical media handling procedures |
| **CA** — Assessment & Authorization | The SA&A process itself — meta-level |
| **RA** (partial) — Risk Assessment | Risk register is a document; however, threat model artifacts in code are assessable |
| **IR** (partial) — Incident Response | IR plans are documents; however, runbook code/alerting config is assessable |

**Key insight from the repo PDF:** Even "policy" controls like AT-2(2) (Security Awareness Training - Insider Threat) appear on evidence cards for a platform, because the platform team must demonstrate *their* training posture. The skill should flag these as "evidence required but not code-derivable" rather than skipping them.

---

## 3. The SA&A Lifecycle

ITSG-33 defines a **six-phase lifecycle** (mirroring NIST RMF):

| Phase | Key activities | Outputs |
|-------|---------------|---------|
| **1. Categorize** | Determine info types, sensitivity, impact levels → assign LOW/MEDIUM/HIGH | System categorization statement |
| **2. Select Controls** | Choose baseline profile, tailor/supplement controls, document rationale | Security Control Profile (SCP) |
| **3. Implement** | Implement selected controls in the system | System implementation, IaC, configs |
| **4. Assess** | Security Assessment (SA) — test whether controls are implemented correctly and operating effectively | Security Assessment Report (SAR) |
| **5. Authorize** | Departmental CIO/Designated Official reviews SAR, accepts residual risk | Authority to Operate (ATO) / Authorization Decision |
| **6. Monitor** | Continuous monitoring, annual reassessment, change management | Ongoing evidence, POA&M updates |

**Where a code assessment skill fits:** Primarily in **Phase 3 → Phase 4** — it can validate that implementation artifacts (IaC, code, configs) satisfy the controls selected in Phase 2, and generate the evidence that feeds Phase 4's SAR. It can also support **Phase 6** by running on each commit to detect drift.

---

## 4. Evidence Cards — Structure and Fields

From the repo's existing evidence card template and the PoC PDF (AC-6 example visible), a compliant evidence card contains:

| Field | Description |
|-------|-------------|
| **Control ID + Name** | e.g., AC-6 — Least Privilege |
| **Risk Level / Profile** | LOW / MEDIUM / HIGH badge |
| **Risk Summary** | What goes wrong if this control is absent |
| **Implementation Approach** | How the platform/system implements this control (narrative + IaC references) |
| **Evidence Artefacts** | Concrete files, logs, tool outputs, or inherited evidence that prove implementation |
| **Client Responsibility** | What the consuming application team must do (shared responsibility) |
| **Inherited Evidence** | `[Inherited]` flag if the control is satisfied by Landing Zone or CSP |

The skill's phase-1 output should map directly to this structure — one card per assessed control.

**No single official CSE template is publicly mandated** — departments adapt the structure. The repo's own `evidenceCard/template-evidenceCard.md` is the operative template for this context.

---

## 5. Canadian-Specific Context

**ITSG-33 vs. NIST SP 800-53:**
- ITSG-33 Annex 3 is almost a direct translation of NIST 800-53 Rev 4 into Canadian federal context
- Key differences: (a) Canadian privacy law (Privacy Act, PIPEDA) shapes PS and PL controls; (b) TBS directives (Directive on Security Management, Policy on Government Security) add mandatory requirements on top; (c) Protected B / Medium / Medium (PBMM) is the dominant cloud profile, not a NIST construct
- ITSG-33 has not been updated to track NIST 800-53 Rev 5 — there is a gap; some departments are applying Rev 5 concepts but the official catalogue is still Rev 4-aligned

**Treasury Board Secretariat (TBS) context:**
- TBS Policy on Government Security and Directive on Security Management are the governance layer above ITSG-33
- The GC Cloud Security Risk Management Approach and Procedures (CSRMAP) applies for cloud systems
- Protected B cloud workloads on SSC Landing Zone / Azure GC Tenant inherit a set of controls from the Landing Zone — these must be marked `[Inherited]` in evidence cards

**CCCS (formerly CSE) cloud guidance:**
- CCCS published cloud-specific security control profiles for AWS, Azure, GCP — these are the operative profiles for GC cloud SA&As
- The "PBMM" profile (Protected B, Medium integrity, Medium availability) is the standard baseline

---

## 6. Existing Tooling and Gaps

| Tool | What it assesses | ITSG-33 gap |
|------|-----------------|-------------|
| **Checkov** | IaC (Terraform, K8s manifests, Helm) — misconfigs against CIS benchmarks, NIST controls | Maps to NIST 800-53 but not ITSG-33 families directly; produces pass/fail, not narrative evidence |
| **tfsec / Trivy** | Terraform/container security misconfigs | Same gap — no ITSG-33 mapping, no evidence card output |
| **OpenSCAP** | OS/container compliance against SCAP profiles (DISA STIG, PCI-DSS) | No Canadian profiles; CLI output, not SA&A-ready |
| **Prowler** | AWS/Azure/GCP cloud config against CIS, NIST 800-53, ISO 27001 | Closest to useful; has NIST 800-53 mapping but not ITSG-33; JSON/HTML output, not evidence cards |
| **Anchore/Grype** | Container vulnerability scanning | Only covers SI-family (vulnerabilities), not broader controls |
| **AWS Security Hub / Azure Defender** | Cloud-native compliance dashboards | Vendor-specific, GC Azure Tenant-specific inherited controls only |

**The critical gap none of them fill:** No existing tool produces **ITSG-33-mapped, evidence-card-structured, narrative output** that a security assessor can use directly in a SAR. They all produce technical pass/fail findings that must be manually translated into SA&A evidence — that translation is exactly what the PoC in the repo PDF demonstrated an LLM can do well.

---

## Conclusions for skill design

1. **Control scope:** The skill should cover the 8 technically-assessable families (AC, AU, CM, IA, SC, SI, SA, CP) and flag the remaining 10 as "evidence required, not code-derivable."
2. **Output format:** Evidence-card per control, matching the existing repo template — this is the right abstraction.
3. **Profile selection:** User must declare LOW/MEDIUM/HIGH at invocation (or PBMM as a named shorthand). The skill cannot infer this from code.
4. **Inherited controls:** The skill must support `[Inherited]` tagging for LZ/CSP-satisfied controls.
5. **Phase 1 → Phase 2 bridge:** Phase 1 produces evidence cards; Phase 2 takes gap cards (where evidence is absent or insufficient) and proposes concrete IaC/code fixes with pre/post test validation.
6. **The unique value:** LLM-generated narrative that bridges technical findings → SA&A-ready evidence language. This is the gap no existing tool fills.
