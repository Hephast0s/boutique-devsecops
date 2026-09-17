# METRICS — measured outcomes

Real numbers captured during the engagement (no estimates).

## Build & pipeline

| Metric | Value | Source |
|---|---|---|
| CI cold build (frontend, Kaniko) | ~6m12s | build #5 |
| Full supply-chain build (2 services: SBOM+scan+sign+attest+verify) | < 15 min | build #11 |
| Failed iterations before green | builds #1–#4 (fixed, documented) | PHASE-4-REPORT |

## Images

| Service | Size |
|---|---|
| frontend (distroless) | 12.1 MB |
| productcatalogservice | 9.8 MB |
| shippingservice | 7.2 MB |
| adservice | 109.5 MB (largest) |
| cartservice | 17.9 MB |

## Vulnerabilities (baseline vs after CI rebuild)

| Image | Mirror C/H fixable | CI rebuild |
|---|---|---|
| frontend | HIGH 15 | **0 C/H** (passes gate) |
| productcatalogservice | HIGH 15 | **0 C/H** (passes gate) |
| shippingservice | HIGH 14 | still failing gate (remediation item) |

## Runtime footprint

| Metric | Value |
|---|---|
| boutique-dev actual usage | **34 mCPU / 216 MiB** |
| boutique-dev requests / limits | 1.17 CPU / 1.09 GiB · 2.33 CPU / 1.98 GiB |
| Latency `GET /` (dev, single client) | p50 19 ms · p95 138 ms |
| Latency `GET /product/{id}` | p50 13 ms · p95 35 ms |

## Availability / operations

| Metric | Value |
|---|---|
| Environments from Git | 3 (dev/staging/prod), digest-pinned |
| Drift self-heal (replica drift) | reverted within ~40 s |
| Secret rotation (Vault → k8s) | applied within ~10 s |
| Rollback (Git revert → applied) | reverted to previous digest |
| Smoke tests | 7/7 across all 3 envs |
| ZAP baseline | FAIL-NEW 0, WARN 12 (all triaged) |

## Gaps (quantified)

- 0 runtime-detection rules (Falco not installed) — CR-003.
- 0 continuous in-cluster vulnerability reports (Trivy Operator not installed) — CR-003.
- 1 of 5 target Grafana dashboards has data (missing exporters/Trivy Operator/Loki).

## Additional measured outcomes (latest)

| Item | Value |
|---|---|
| CI-signed services (SBOM+sign+attest+verify) | **3** (frontend, productcatalogservice, checkoutservice) |
| checkoutservice SBOM | 997 components |
| kube-bench (control-plane, k3s) | 9 PASS / 7 FAIL / 37 WARN |
| Prometheus alert firing | `BoutiqueDeploymentReplicasMismatch` fired on a faulty workload (evidence: `docs/evidence/phase11/alert-firing.txt`) |
| Harbor project config | immutable tag rule (`v*`) + retention (keep last 10) + pull robot |
| Trivy Operator config-audit reports | 119 (+1 exposed secret) |
| Jenkins CI branch tracking | fixed to `devsecops` (was pointing at a deleted branch) |
| CI agents vs admission policy | `boutique-ci` unlabelled so app policies don't block agents |
