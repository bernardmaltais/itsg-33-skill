# ITSG-33 Code-Assessable Controls Analysis

**Derived from:** itsg-33-control-catalogue.md + itsg-33-saa-lifecycle.md  
**Purpose:** Informs which ITSG-33 controls the assessment skill can evaluate by reading code, IaC, and config files vs. those requiring human/process evidence.

---

## Classification Framework

Controls are classified into three buckets:

| Bucket | Description |
|--------|-------------|
| **Code-assessable** | Can be evaluated by reading source code, IaC (Terraform, Helm, K8s manifests), config files, CI/CD pipelines, or dependency manifests |
| **Partially assessable** | Some sub-controls or enhancements are code-assessable; others require process/document evidence |
| **Process-only** | Cannot be assessed from a repo — requires HR records, policy documents, physical inspections, training logs, etc. |

---

## Code-Assessable Families

### AC — Access Control (Technical)
**Assessable controls:**
- AC-2: Account Management — service accounts defined in IaC, RBAC role bindings
- AC-3: Access Enforcement — RBAC policies, OPA/Kyverno rules, IAM policies in Terraform
- AC-4: Information Flow Enforcement — network policies, firewall rules, ingress/egress controls in IaC
- AC-5: Separation of Duties — role separation in RBAC manifests, pipeline approval gates
- AC-6: Least Privilege — scoped roles, no cluster-admin bindings, workload identity mappings
- AC-7: Unsuccessful Login Attempts — auth middleware config, rate limiting config
- AC-8: System Use Notification — login banner config in code
- AC-11: Session Lock — session timeout config in app code
- AC-12: Session Termination — session management in app code
- AC-17: Remote Access — VPN/bastion config, SSH key management in IaC
- AC-19: Access Control for Mobile Devices — MDM policy config, conditional access policies in IaC

**Not assessable from code:** AC-1 (policy doc), AC-9/AC-13 (review processes), AC-21 (collaboration agreements)

---

### AU — Audit and Accountability (Technical)
**Assessable controls:**
- AU-2: Auditable Events — logging config (what events are logged)
- AU-3: Content of Audit Records — log format and field config
- AU-4: Audit Storage Capacity — log storage allocation in IaC
- AU-5: Response to Audit Processing Failures — alerting config for log pipeline failures
- AU-8: Time Stamps — NTP/clock config, log timestamp format
- AU-9: Protection of Audit Information — RBAC on log storage, log immutability config
- AU-11: Audit Record Retention — log retention policy config
- AU-12: Audit Generation — audit logging enabled in app/platform config

**Partially assessable:** AU-6 (review process + tooling config), AU-7 (SIEM config assessable; human review process not)

---

### IA — Identification and Authentication (Technical)
**Assessable controls:**
- IA-2: Identification and Authentication — auth provider config, MFA enforcement in IaC
- IA-3: Device Identification and Authentication — certificate config, device auth policies
- IA-4: Identifier Management — account naming conventions, auto-disable config
- IA-5: Authenticator Management — password policy config, credential rotation in Terraform/Vault
- IA-6: Authenticator Feedback — login form config (no plaintext password display)
- IA-7: Cryptographic Module Authentication — crypto library and FIPS config
- IA-8: Identification and Authentication (Non-Org Users) — external IdP config
- IA-9: Service Identification and Authentication — service mesh mTLS config, API key management

---

### SC — System and Communications Protection (Technical)
**Assessable controls:**
- SC-2: Application Partitioning — namespace isolation, service mesh config
- SC-5: Denial of Service Protection — rate limiting, resource quotas in IaC
- SC-7: Boundary Protection — firewall rules, network policies, WAF config in IaC
- SC-8: Transmission Confidentiality and Integrity — TLS config, cipher suites
- SC-12: Cryptographic Key Establishment and Management — KMS/Vault config in IaC
- SC-13: Cryptographic Protection — encryption settings in code and IaC
- SC-17: Public Key Infrastructure Certificates — cert-manager config, CA config
- SC-18: Mobile Code — CSP headers, script-src policies in app config
- SC-23: Session Authenticity — session token config, CSRF protection
- SC-28: Protection of Information at Rest — volume encryption, database encryption config
- SC-39: Process Isolation — container security contexts, seccomp profiles

---

### CM — Configuration Management (Operational)
**Assessable controls:**
- CM-2: Baseline Configuration — IaC defines the baseline; drift detectable by comparing IaC to live state
- CM-3: Configuration Change Control — Git branch protection, PR approval requirements (assessable from repo settings)
- CM-5: Access Restrictions for Change — CODEOWNERS, branch protection rules
- CM-6: Configuration Settings — hardening configs, CIS benchmark adherence in IaC
- CM-7: Least Functionality — disabled services, minimal base images
- CM-8: Information System Component Inventory — SBOM, dependency manifests (package.json, go.mod, requirements.txt)
- CM-10: Software Usage Restrictions — license scanning config
- CM-11: User Installed Software — image build constraints, admission controllers

---

### SI — System and Information Integrity (Operational)
**Assessable controls:**
- SI-2: Flaw Remediation — dependency versions, vulnerability scanning CI config, Dependabot config
- SI-3: Malicious Code Protection — container image scanning config, admission webhooks
- SI-4: Information System Monitoring — monitoring/alerting config (Prometheus rules, Grafana dashboards as code)
- SI-7: Software, Firmware, and Information Integrity — image signing config, admission controller policies
- SI-10: Information Input Validation — input validation code patterns
- SI-11: Error Handling — error handling patterns in code (no stack traces to end users)
- SI-16: Memory Protection — compiler flags, container security contexts

---

### SA — System and Services Acquisition (Management, partial)
**Assessable controls:**
- SA-10: Developer Configuration Management — .gitignore, branch strategy, commit signing config
- SA-11: Developer Security Testing — CI security test config (SAST, DAST, dependency scan)
- SA-15: Development Process, Standards, and Tools — CI/CD pipeline definition, linting configs
- SA-22: Unsupported System Components — EOL dependency detection in manifests

---

### CP — Contingency Planning (Operational, partial)
**Assessable controls:**
- CP-9: Information System Backup — backup config in IaC (schedules, retention, replication)
- CP-10: Information System Recovery and Reconstitution — recovery scripts, DR config in IaC

---

### RA — Risk Assessment (Management, partial)
**Assessable controls:**
- RA-5: Vulnerability Scanning — scanner config files (Trivy, Grype, Checkov), scan results in CI

---

## Process-Only Families (Cannot Be Assessed From Code)

| Family | Why |
|--------|-----|
| **AT** — Awareness & Training | Training records are HR/LMS artifacts |
| **PL** — Planning | System Security Plan, Rules of Behaviour are documents |
| **CA** — Assessment & Authorization | The SA&A process itself; penetration test reports are external |
| **MA** — Maintenance | Maintenance procedures, physical access logs |
| **MP** — Media Protection | Physical media handling procedures |
| **PE** — Physical & Environmental | Physical access controls, data centre posture |
| **PS** — Personnel Security | Background checks, personnel agreements |
| **IR** (mostly) | IR plans are documents; only alerting/runbook code is assessable |
| **CP** (mostly) | Contingency plans are documents; only backup/recovery config is assessable |
| **SA** (mostly) | Acquisition processes, vendor screening are not in code |
| **RA** (mostly) | Risk registers, TRA reports are documents |

---

## Summary Counts

| Bucket | Families |
|--------|---------|
| Primarily code-assessable | AC, AU, IA, SC, CM, SI (6 families, ~100+ controls total) |
| Partially assessable | SA, CP, RA, IR (4 families, ~10–15 assessable controls) |
| Process-only | AT, PL, CA, MA, MP, PE, PS (7 families — flag as "evidence required, not code-derivable") |
