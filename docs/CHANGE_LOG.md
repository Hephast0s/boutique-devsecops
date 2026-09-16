# CHANGE_LOG

Every object this engagement creates, with the exact create and remove command.
Cluster/remote objects are listed only from Phase 1 onward (nothing has been created remotely yet).

## Phase 0 — local repository files (no cluster writes)

All items below are new files in the working tree. They touch **nothing** outside the repository and are
not yet committed or pushed. Removal = `rm <path>` (only if abandoning the engagement).

| Created | Path | Purpose |
|---|---|---|
| 2026-09-16 | `docs/STATE.md` | session handoff / resume file |
| 2026-09-16 | `OPERATOR_ANSWERS.md` | Section 0 facts, confirmed vs missing |
| 2026-09-16 | `docs/00-application-analysis.md` | per-service analysis |
| 2026-09-16 | `docs/00-architecture.md` | component/flow/trust-boundary model |
| 2026-09-16 | `docs/00-threat-model.md` | STRIDE + 20-risk register + traceability |
| 2026-09-16 | `docs/00-build-matrix.md` | authoritative build table |
| 2026-09-16 | `ci/services.yaml` | machine-readable CI matrix (12 services) |
| 2026-09-16 | `docs/phases/PHASE-0-REPORT.md` | phase report |
| 2026-09-16 | `docs/CHANGE_LOG.md` | this file |
| 2026-09-16 | `docs/ROLLBACK.md` | teardown plan |

Read-only commands were run against the cluster (preflight only). **No Kubernetes, Gitea, Harbor, Vault,
Nexus, Jenkins or Grafana object was created, modified or deleted.** No upstream file was modified.

## Phase 1 — infrastructure discovery (read-only + one sanctioned write)

Read-only: `kubectl get/describe/top`, `helm list`, `curl` health probes. No existing object changed.

**Sanctioned temporary write (announced, logged, cleaned up):**
| Action | Exact create | Exact remove |
|---|---|---|
| egress test namespace | `kubectl create ns boutique-preflight` | `kubectl delete ns boutique-preflight` |
| egress test pod | `kubectl -n boutique-preflight run egress --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep 300` | removed with the namespace |

Cleanup proven: `kubectl get ns boutique-preflight` → `NotFound` (0 pods remaining).

Local files created: `docs/01-agent-capabilities.md`, `docs/01-infrastructure-inventory.md`,
`docs/01-capability-matrix.md`, `docs/01-capacity-budget.md`, `docs/01-ADR-0001-platform-choices.md`,
`docs/CHANGE_REQUESTS.md`, `docs/phases/PHASE-1-REPORT.md`; restore-point export under
`docs/evidence/pre-engagement/`.

**Deviation (operator-directed):** changes are committed and pushed to the GitHub fork
`origin=https://github.com/MinaC4/microservices-demo.git` because Gitea is scaled to 0. This is not the
Google upstream. See `CHANGE_REQUESTS.md` CR-010.

## Phase 2+ — (empty; populated as objects are created)
