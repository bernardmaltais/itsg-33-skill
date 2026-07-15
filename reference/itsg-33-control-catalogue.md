# ITSG-33 Control Catalogue Reference

**Source:** Canadian Centre for Cyber Security (CCCS) — cyber.gc.ca  
**Document:** IT Security Risk Management: A Lifecycle Approach (ITSG-33), Annex 3A  
**Fetched:** 2026-07-15

---

## Document Structure

ITSG-33 consists of:

| Annex | Title |
|-------|-------|
| Overview | IT Security Risk Management: A Lifecycle Approach |
| Annex 1 | Departmental IT Security Risk Management Activities |
| Annex 2 | Information System Security Risk Management Activities (ISSIP — the SA&A lifecycle) |
| Annex 3A | Security Control Catalogue |
| Annex 4A Profile 1 | PROTECTED B / Medium Integrity / Medium Availability |
| Annex 4A Profile 3 | SECRET / Medium Integrity / Medium Availability |
| Annex 5 | Glossary |

---

## Control Classes and Families

Controls are organized into **3 classes** and **18 families**:

### Technical Class
| ID | Family |
|----|--------|
| AC | Access Control (25 controls) |
| AU | Audit and Accountability (16 controls) |
| IA | Identification and Authentication (11 controls) |
| SC | System and Communications Protection (44+ controls, incl. Canadian-specific) |

### Operational Class
| ID | Family |
|----|--------|
| AT | Awareness and Training (5 controls) |
| CM | Configuration Management (11 controls) |
| CP | Contingency Planning (13 controls) |
| IR | Incident Response (10 controls) |
| MA | Maintenance (6 controls) |
| MP | Media Protection (8 controls) |
| PE | Physical and Environmental Protection (20 controls) |
| PS | Personnel Security (8 controls) |
| SI | System and Information Integrity (17 controls) |

### Management Class
| ID | Family |
|----|--------|
| CA | Security Assessment and Authorization (9 controls) |
| PL | Planning (9 controls) |
| RA | Risk Assessment (6 controls) |
| SA | System and Services Acquisition (22 controls) |

---

## Canadian-Specific Controls

Controls numbered **≥100** are Canada-specific additions beyond NIST SP 800-53 Rev 4:

- **SC-100** — Source Authentication
- **SC-101** — Unclassified Telecommunications Systems in Secure Facilities

Canadian-specific statements within controls use the **"AA" designator** (e.g., AC-17 (AA)).  
Canadian-specific enhancements start at **100** (e.g., AC-17 (100)).

---

## Full Control List

### Access Control (AC) — Technical

| ID | Name | Enhancements |
|----|------|-------------|
| AC-1 | Access Control Policy and Procedures | None |
| AC-2 | Account Management | 1–13 |
| AC-3 | Access Enforcement | 1–10 (1 withdrawn→AC-6; 6 withdrawn→MP-4/SC-28) |
| AC-4 | Information Flow Enforcement | 1–22 (16 withdrawn→AC-4) |
| AC-5 | Separation of Duties | None |
| AC-6 | Least Privilege | 1–10 |
| AC-7 | Unsuccessful Login Attempts | 1–2 (1 withdrawn) |
| AC-8 | System Use Notification | Yes |
| AC-9 | Previous Logon Notification | — |
| AC-10 | Concurrent Session Control | — |
| AC-11 | Session Lock | — |
| AC-12 | Session Termination | — |
| AC-13 | Supervision and Review — Access Control | — |
| AC-14 | Permitted Actions Without ID or Authentication | — |
| AC-15 | Automated Marking | — |
| AC-16 | Security Attributes | — |
| AC-17 | Remote Access | Yes (incl. enhancement 9, AA) |
| AC-18 | Wireless Access | — |
| AC-19 | Access Control for Mobile Devices | — |
| AC-20 | Use of External Information Systems | — |
| AC-21 | User-Based Collaboration and Information Sharing | — |
| AC-22 | Publicly Accessible Content | — |
| AC-23 | Data Mining Protection | — |
| AC-24 | Access Control Decisions | — |
| AC-25 | Reference Monitor | — |

### Audit and Accountability (AU) — Technical

| ID | Name |
|----|------|
| AU-1 | Audit and Accountability Policy and Procedures |
| AU-2 | Auditable Events |
| AU-3 | Content of Audit Records |
| AU-4 | Audit Storage Capacity |
| AU-5 | Response to Audit Processing Failures |
| AU-6 | Audit Review, Analysis, and Reporting |
| AU-7 | Audit Reduction and Report Generation |
| AU-8 | Time Stamps |
| AU-9 | Protection of Audit Information |
| AU-10 | Non-Repudiation |
| AU-11 | Audit Record Retention |
| AU-12 | Audit Generation |
| AU-13 | Monitoring for Information Disclosure |
| AU-14 | Session Audit |
| AU-15 | Alternate Audit Capability |
| AU-16 | Cross-Organizational Auditing |

### Identification and Authentication (IA) — Technical

| ID | Name |
|----|------|
| IA-1 | Identification and Authentication Policy and Procedures |
| IA-2 | Identification and Authentication (Organizational Users) |
| IA-3 | Device Identification and Authentication |
| IA-4 | Identifier Management |
| IA-5 | Authenticator Management |
| IA-6 | Authenticator Feedback |
| IA-7 | Cryptographic Module Authentication |
| IA-8 | Identification and Authentication (Non-Organizational Users) |
| IA-9 | Service Identification and Authentication |
| IA-10 | Adaptive Identification and Authentication |
| IA-11 | Re-Authentication |

### System and Communications Protection (SC) — Technical

| ID | Name | Notes |
|----|------|-------|
| SC-1 | System and Communications Protection Policy and Procedures | |
| SC-2 | Application Partitioning | |
| SC-3 | Security Function Isolation | |
| SC-4 | Information in Shared Resources | |
| SC-5 | Denial of Service Protection | |
| SC-6 | Resource Availability | |
| SC-7 | Boundary Protection | |
| SC-8 | Transmission Confidentiality and Integrity | |
| SC-9 | Transmission Confidentiality | |
| SC-10 | Network Disconnect | |
| SC-11 | Trusted Path | |
| SC-12 | Cryptographic Key Establishment and Management | |
| SC-13 | Cryptographic Protection | |
| SC-14 | Public Access Protections | |
| SC-15 | Collaborative Computing Devices | |
| SC-16 | Transmission of Security Attributes | |
| SC-17 | Public Key Infrastructure Certificates | |
| SC-18 | Mobile Code | |
| SC-19 | Voice Over Internet Protocol | |
| SC-20 | Secure Name/Address Resolution Service (Authoritative Source) | |
| SC-21 | Secure Name/Address Resolution Service (Recursive/Caching) | |
| SC-22 | Architecture and Provisioning for Name/Address Resolution | |
| SC-23 | Session Authenticity | |
| SC-24 | Fail in Known State | |
| SC-25 | Thin Nodes | |
| SC-26 | Honeypots | |
| SC-27 | Platform-Independent Applications | |
| SC-28 | Protection of Information at Rest | |
| SC-29 | Heterogeneity | |
| SC-30 | Concealment and Misdirection | |
| SC-31 | Covert Channel Analysis | |
| SC-32 | Information System Partitioning | |
| SC-33 | Transmission Preparation Integrity | |
| SC-34 | Non-Modifiable Executable Programs | |
| SC-35 | Honeyclients | |
| SC-36 | Distributed Processing and Storage | |
| SC-37 | Out-of-Band Channels | |
| SC-38 | Operations Security | |
| SC-39 | Process Isolation | |
| SC-40 | Wireless Link Protection | |
| SC-41 | Port and I/O Device Access | |
| SC-42 | Sensor Capability and Data | |
| SC-43 | Usage Restrictions | |
| SC-44 | Detonation Chambers | |
| **SC-100** | **Source Authentication** | **Canadian-specific** |
| **SC-101** | **Unclassified Telecommunications Systems in Secure Facilities** | **Canadian-specific** |

### Awareness and Training (AT) — Operational

| ID | Name |
|----|------|
| AT-1 | Security Awareness and Training Policy and Procedures |
| AT-2 | Security Awareness |
| AT-3 | Role Based Security Training |
| AT-4 | Security Training Records |
| AT-5 | Contacts with Security Groups and Associations |

### Configuration Management (CM) — Operational

| ID | Name |
|----|------|
| CM-1 | Configuration Management Policy and Procedures |
| CM-2 | Baseline Configuration |
| CM-3 | Configuration Change Control |
| CM-4 | Security Impact Analysis |
| CM-5 | Access Restrictions for Change |
| CM-6 | Configuration Settings |
| CM-7 | Least Functionality |
| CM-8 | Information System Component Inventory |
| CM-9 | Configuration Management Plan |
| CM-10 | Software Usage Restrictions |
| CM-11 | User Installed Software |

### Contingency Planning (CP) — Operational

| ID | Name |
|----|------|
| CP-1 | Contingency Planning Policy and Procedures |
| CP-2 | Contingency Plan |
| CP-3 | Contingency Training |
| CP-4 | Contingency Plan Testing and Exercises |
| CP-5 | Contingency Plan Update |
| CP-6 | Alternate Storage Site |
| CP-7 | Alternate Processing Site |
| CP-8 | Telecommunications Services |
| CP-9 | Information System Backup |
| CP-10 | Information System Recovery and Reconstitution |
| CP-11 | Alternate Communications Protocols |
| CP-12 | Safe Mode |
| CP-13 | Alternative Security Mechanisms |

### Incident Response (IR) — Operational

| ID | Name |
|----|------|
| IR-1 | Incident Response Policy and Procedures |
| IR-2 | Incident Response Training |
| IR-3 | Incident Response Testing and Exercises |
| IR-4 | Incident Handling |
| IR-5 | Incident Monitoring |
| IR-6 | Incident Reporting |
| IR-7 | Incident Response Assistance |
| IR-8 | Incident Response Plan |
| IR-9 | Information Spillage Response |
| IR-10 | Integrated Information Security Analysis Team |

### Maintenance (MA) — Operational

| ID | Name |
|----|------|
| MA-1 | System Maintenance Policy and Procedures |
| MA-2 | Controlled Maintenance |
| MA-3 | Maintenance Tools |
| MA-4 | Non-Local Maintenance |
| MA-5 | Maintenance Personnel |
| MA-6 | Timely Maintenance |

### Media Protection (MP) — Operational

| ID | Name |
|----|------|
| MP-1 | Media Protection Policy and Procedures |
| MP-2 | Media Access |
| MP-3 | Media Marking |
| MP-4 | Media Storage |
| MP-5 | Media Transport |
| MP-6 | Media Sanitization |
| MP-7 | Media Use |
| MP-8 | Media Downgrading |

### Physical and Environmental Protection (PE) — Operational

| ID | Name |
|----|------|
| PE-1 | Physical and Environmental Protection Policy and Procedures |
| PE-2 | Physical Access Authorizations |
| PE-3 | Physical Access Control |
| PE-4 | Access Control for Transmission Medium |
| PE-5 | Access Control for Output Devices |
| PE-6 | Monitoring Physical Access |
| PE-7 | Visitor Control |
| PE-8 | Access Records |
| PE-9 | Power Equipment and Power Cabling |
| PE-10 | Emergency Shutoff |
| PE-11 | Emergency Power |
| PE-12 | Emergency Lighting |
| PE-13 | Fire Protection |
| PE-14 | Temperature and Humidity Controls |
| PE-15 | Water Damage Protection |
| PE-16 | Delivery and Removal |
| PE-17 | Alternate Work Site |
| PE-18 | Location of Information System Components |
| PE-19 | Information Leakage |
| PE-20 | Asset Monitoring and Tracking |

### Personnel Security (PS) — Operational

| ID | Name |
|----|------|
| PS-1 | Personnel Security Policy and Procedures |
| PS-2 | Position Categorization |
| PS-3 | Personnel Screening |
| PS-4 | Personnel Termination |
| PS-5 | Personnel Transfer |
| PS-6 | Access Agreements |
| PS-7 | Third-Party Personnel Security |
| PS-8 | Personnel Sanctions |

### System and Information Integrity (SI) — Operational

| ID | Name |
|----|------|
| SI-1 | System and Information Integrity Policy and Procedures |
| SI-2 | Flaw Remediation |
| SI-3 | Malicious Code Protection |
| SI-4 | Information System Monitoring |
| SI-5 | Security Alerts, Advisories, and Directives |
| SI-6 | Security Functional Verification |
| SI-7 | Software, Firmware, and Information Integrity |
| SI-8 | Spam Protection |
| SI-9 | Information Input Restrictions |
| SI-10 | Information Input Validation |
| SI-11 | Error Handling |
| SI-12 | Information Output Handling and Retention |
| SI-13 | Predictable Failure Prevention |
| SI-14 | Non-Persistence |
| SI-15 | Information Output Filtering |
| SI-16 | Memory Protection |
| SI-17 | Fail-Safe Procedures |

### Security Assessment and Authorization (CA) — Management

| ID | Name |
|----|------|
| CA-1 | Security Assessment and Authorization Policies and Procedures |
| CA-2 | Security Assessments |
| CA-3 | Information System Connections |
| CA-4 | Security Certification |
| CA-5 | Plan of Action and Milestones |
| CA-6 | Security Authorization |
| CA-7 | Continuous Monitoring |
| CA-8 | Penetration Testing |
| CA-9 | Internal System Connections |

### Planning (PL) — Management

| ID | Name |
|----|------|
| PL-1 | Security Planning Policy and Procedures |
| PL-2 | System Security Plan |
| PL-3 | System Security Plan Update |
| PL-4 | Rules of Behaviour |
| PL-5 | Privacy Impact Assessment |
| PL-6 | Security-Related Activity Planning |
| PL-7 | Security Concepts of Operation |
| PL-8 | Information Security Architecture |
| PL-9 | Central Management |

### Risk Assessment (RA) — Management

| ID | Name |
|----|------|
| RA-1 | Risk Assessment Policy and Procedures |
| RA-2 | Security Categorization |
| RA-3 | Risk Assessment |
| RA-4 | Risk Assessment Update |
| RA-5 | Vulnerability Scanning |
| RA-6 | Technical Surveillance Countermeasures Survey |

### System and Services Acquisition (SA) — Management

| ID | Name |
|----|------|
| SA-1 | System and Services Acquisition Policy and Procedures |
| SA-2 | Allocation of Resources |
| SA-3 | System Development Lifecycle |
| SA-4 | Acquisition Process |
| SA-5 | Information System Documentation |
| SA-6 | Software Usage Restrictions |
| SA-7 | User-Installed Software |
| SA-8 | Security Engineering Principles |
| SA-9 | External Information System Services |
| SA-10 | Developer Configuration Management |
| SA-11 | Developer Security Testing |
| SA-12 | Supply Chain Protection |
| SA-13 | Trustworthiness |
| SA-14 | Criticality Analysis |
| SA-15 | Development Process, Standards, and Tools |
| SA-16 | Developer Provided Training |
| SA-17 | Developer Security Architecture and Design |
| SA-18 | Tamper Resistance and Detection |
| SA-19 | Component Authenticity |
| SA-20 | Customized Development of Critical Components |
| SA-21 | Developer Screening |
| SA-22 | Unsupported System Components |

---

## Security Profiles

Profiles are in **Annex 4A**. The two publicly available profiles are:

| Profile | Sensitivity | Threat Agents Addressed |
|---------|------------|------------------------|
| **Profile 1 (PBMM)** | Protected B / Medium Integrity / Medium Availability | Td1–Td4 (not Td5–Td7) |
| **Profile 3** | SECRET / Medium Integrity / Medium Availability | Higher threat actors |

**PBMM (Protected B / Medium / Medium)** is the dominant profile for GC cloud workloads.

Profile 1 uses:
- **Security Assurance Levels:** SAL2 for most controls; SAL3 for boundary/critical controls
- **Priority tiers:** P1, P2, P3 (determines implementation order)
- **Responsible parties per control:** IT Security, IT Ops, IT Projects, Physical/Personnel Security, Learning Center

The specific control selection list (Table 4) is only in the PDF version of Annex 4A Profile 1 — not available in the web version.

---

## Sources

- https://www.cyber.gc.ca/en/guidance/it-security-risk-management-lifecycle-approach-itsg-33
- https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33
- https://www.cyber.gc.ca/en/guidance/annex-4a-profile-1-protected-b-medium-integrity-medium-availability-itsg-33
- https://www.cyber.gc.ca/en/guidance/annex-2-information-system-security-risk-management-activities-itsg-33
