# sample-app fixture

A minimal but realistic GC cloud workload used to test `itsg-33-assess` and `itsg-33-remediate`.

## What it represents

A Protected B Python web application deployed on AKS (Azure Kubernetes Service) on the SSC Landing Zone, using Azure storage, Key Vault, and a GitHub Actions CI pipeline.

## Deliberate findings

| Control | Finding | Why |
|---------|---------|-----|
| AC-6 | **Fail** | `cluster-admin` ClusterRoleBinding + Contributor IAM role (too broad) |
| SC-28 | **Fail** | Storage account has no encryption-at-rest config |
| AU-2 | **Fail** | No audit logging config anywhere |
| AU-3 | **Fail** | No log format or record field config |
| AU-12 | **Fail** | No audit log generation enabled |
| SI-10 | **Fail** | SQL injection in `/items` endpoint (string concatenation) |

## Deliberate passes

| Control | Finding | Why |
|---------|---------|-----|
| SC-7 | **Pass** | Default-deny NetworkPolicy + NSG with explicit rules |
| SC-12 | **Pass** | Key Vault with purge protection and network ACL default-deny |
| SC-39 | **Pass** | Container securityContext fully hardened |
| SI-2 | **Pass** | Dependabot + Trivy scan in CI |
| SI-3 | **Pass** | Container image scan in CI |
| CP-9 | **Pass** | Recovery Services Vault + backup policy |
| SA-11 | **Pass** | Semgrep SAST + Trivy in CI |

## Full expected findings

See `expected-findings.yaml` for the complete per-control finding, reason, and evidence file reference.

## File structure

```
sample-app/
├── terraform/
│   └── main.tf              ← Azure IaC (storage, Key Vault, NSG, IAM, backup)
├── k8s/
│   ├── rbac.yaml            ← RBAC (cluster-admin binding = AC-6 Fail)
│   └── deployment.yaml      ← Pod spec, NetworkPolicy, ResourceQuota
├── app/
│   └── main.py              ← Flask app (SI-10 Fail, SI-11 Pass)
├── .github/
│   ├── workflows/
│   │   └── ci.yaml          ← GitHub Actions (SA-11 Pass, CM-3 Pass)
│   └── dependabot.yml       ← Dependabot config (SI-2 Pass)
├── Dockerfile               ← Minimal Python image (CM-7 Pass)
├── requirements.txt         ← Pinned dependencies (CM-8 Pass)
└── expected-findings.yaml  ← Ground truth for verification
```
