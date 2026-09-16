# 09 — Runtime Security (status)

This document records the runtime-security layer honestly, including what is **blocked** and why.

## Implemented

- **Network segmentation** enforced (see `09-network-security.md`) — proven with allowed/blocked tests.
- **Admission control** enforced (Phase 8) — `boutique-*` pods must be non-root, drop ALL caps,
  read-only rootfs, seccomp RuntimeDefault, resource-bounded, probe-guarded, digest-pinned from Harbor.

## Blocked — awaiting install permission (CR-003)

| Component | Purpose | Blocker |
|---|---|---|
| **Falco** (+ falcosidekick) | runtime detection (shell spawn, unexpected egress, SA-token read, crypto-miners) | `may_install_falco` unanswered; adds ~512 Mi/node (DaemonSet) |
| **Trivy Operator** | continuous VulnerabilityReports/ConfigAuditReports per workload + Prometheus metrics | `may_install_trivy_operator` unanswered; spawns scan Jobs (resource cost) |
| **kube-bench** | CIS benchmark of the k3s nodes (one-shot Job) | needs host access; one-shot but privileged |

These are **not installed** because they add cluster-scoped components and would exceed the operator's
4 GiB resource cap if installed together without review. Installing them requires an explicit decision;
the design (rule sets, scoping to `boutique-*`, Loki absence) is captured so they can be added quickly.

## Consequence (stated honestly)

There is currently **no runtime detection** for malicious in-container behaviour, and **no continuous
in-cluster vulnerability scanning**. These are real gaps versus the target design; the compensating
controls are admission policy (Phase 8), image scanning in CI (Phase 5), and network segmentation
(Phase 9.1). The gaps are tracked in `docs/CHANGE_REQUESTS.md` (CR-003).

## Note on Loki

Log aggregation is also absent (no Loki in the cluster). If Falco is added, its alerts would be routed
to Alertmanager webhook / archived files rather than Loki, unless Loki is installed too (also under the
4 GiB cap review).
