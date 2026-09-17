# 09 — Runtime Security (final status)

## Implemented

- **Network segmentation** enforced (see `09-network-security.md`) — proven with allowed/blocked tests.
- **Admission control** enforced (Phase 8).
- **Trivy Operator** installed (`trivy-system`, v0.36.0 chart) — **ConfigAuditReports and
  ExposedSecretReports are being produced** for the boutique namespaces (119 config-audit reports at the
  time of writing, 1 exposed-secret report). Vulnerability scanning was **disabled** after it drove node
  CPU to ~70% and its DB-download init containers did not complete within a reasonable window on this
  3-node cluster (recorded below and in `docs/CHANGE_REQUESTS.md`).

```
trivy-operator (trivy-system): Running, targetNamespaces=boutique-dev,boutique-staging,boutique-prod
configauditreports (boutique-*): 119
exposedsecretreports (boutique-*): 1
vulnerabilityScannerEnabled=false  (capacity)
```

## Falco — attempted, not usable on this homelab (honest outcome)

Falco was installed (`falco/falco`, chart → image `falcosecurity/falco:0.44.1`) with the `modern_ebpf`
driver. It **started and detected real events** — the log recorded:

```
Events detected: 12
Rule counts by severity: NOTICE: 12
Triggered rules by rule name: Contact K8S API Server From Container: 12
```

However, the DaemonSet then entered `CrashLoopBackOff` on 2 of 3 nodes with a driver bug:

```
libpman: disabled BPF iterators (not running in the root PID namespace, ...)
Error: could not parse param 2 (name) for event 60208 of type 307 (openat), ...
```

and a Go panic in the container-plugin fetcher (`fetcher.go:107`). The legacy `driver.kind=ebpf` is no
longer supported by the chart. Because a crash-looping DaemonSet adds noise and resource pressure without
reliable detection, **Falco was uninstalled**; the cluster was verified stable afterwards (all
environments HTTP 200).

Custom rules authored and ready: `security/falco/boutique-rules.yaml` (shell spawn, money-path egress,
SA-token read, package manager, crypto-mining).

## Honest gaps

| Component | Status |
|---|---|
| Falco runtime detection | **not running** — kernel/driver incompatibility on this homelab (evidence above) |
| Trivy Operator vulnerability scanning | **disabled** — capacity (recorded) |
| Trivy Operator config/secret auditing | ✅ working |
| Loki log aggregation | **not installed** — capacity |
| kube-bench | not run (privileged one-shot) |

Compensating controls: admission policy (Phase 8), CI image scanning (Phase 5), network segmentation
(Phase 9.1), Trivy Operator config auditing.
