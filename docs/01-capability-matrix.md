# 01 — Capability Matrix

For each capability the design needs: present / absent / partial, what exists, what must be added,
resource cost, and the fallback if it cannot be added. Resource costs are planning estimates and are
reconciled with measured free capacity in `01-capacity-budget.md`.

| Capability | State | What exists | What must be added | est. cost | Fallback / consequence |
|---|---|---|---|---|---|
| Container registry | **PRESENT** | Harbor 2.15.1, healthy, Trivy scanner enabled, projects `apps`/`hephastos`/`library` | new project `boutique`; push robot + pull robot | none | use an existing public project (undesirable) |
| SBOM storage | **PARTIAL** | Harbor can store cosign attestations (OCI); MinIO in `observability` | nothing new; store SBOMs as cosign attestations + Jenkins archive + optional MinIO raw bucket | none | Jenkins artifacts only |
| Image signing | **PRESENT (tool)** | cosign v2.6.4 locally; no key yet | generate keypair, store private key in Vault, expose to Jenkins as credential | none | none |
| Policy engine | **PRESENT** | Kyverno v1.18.2 (8 policies, scoped to `hephastos`), policy-reporter, `imagevalidatingpolicies` CRD, `policyexceptions` CRD | new `boutique-*`-scoped policies (verifyImages, restricted, limits, latest, labels, netpol-generate) | ~0 (already running; +minor report volume) | Kyverno admission for the namespace only |
| GitOps controller | **PRESENT (2!)** | Argo CD v3.4.5 (active: `hephastos-dashboard`); Devtron 2.2.0 also running | register a new Argo Project + Applications for `boutique-*` | ~0 | pick Devtron instead (see ADR-0001); only one may own the namespaces |
| Secrets manager | **PRESENT** | Vault 2.0.3 (unsealed) | scoped KV v2 mount `boutique/`, k8s auth role + policy, AppRole for Jenkins | ~0 | none (Vault already runs) |
| Secret delivery | **PRESENT** | External Secrets Operator v2.9.0 | new `SecretStore` in `boutique-security` + `ExternalSecret`s (the pre-existing store is InvalidProviderConfig — we do not repair it) | ~0 | Kubernetes Secrets via sealed-secrets (not installed) |
| Metrics | **PRESENT** | kube-prometheus-stack v0.92.1, Grafana (30084), Prometheus (30083), operators CRDs (ServiceMonitor/PodMonitor) | ServiceMonitor/PodMonitor for `boutique-*`; new Grafana dashboards in a new folder | scraping overhead only | manual scrape configs (would edit shared config → needs approval) |
| Tracing | **PRESENT** | OTel collector 0.158.0 + Jaeger (30094) | enable `ENABLE_TRACING` for boutique + point at collector (optional) | small | tracing off (default) |
| Log aggregation | **ABSENT** | none (no Loki/Promtail/Fluent Bit) | Falco log routing target missing → either install Loki (new component) or route Falco alerts elsewhere | Loki ~300–500 Mi + storage | **documented gap**: no centralized logs; Falco alerts can go to Alertmanager webhook / files instead |
| Runtime security | **ABSENT** | none (no Falco) | install Falco (modern eBPF) + falcosidekick | ~512 Mi/node (×3) + CPU | if not permitted: rely on Kyverno + Trivy Operator only; document loss of runtime detection |
| Cluster vulnerability scanning | **ABSENT** | Harbor Trivy scans images on push; no in-cluster scanning | Trivy Operator (namespaced to `boutique-*`) | ~256 Mi | `trivy image` runs in CI only; no continuous drift view |
| CIS benchmark | **ABSENT (local tool)** | none | kube-bench as a one-shot Job (ad-hoc) | transient | none |
| Artifact caching | **ABSENT** | no Nexus | nothing installable identified; use PVC-backed caches per toolchain | PV space | **cold builds every time**; egress is stable so acceptable but slow (documented) |
| DAST runner | **ABSENT (tool)** | ZAP not present; egress available | run ZAP as ephemeral Job (image pull) in staging | transient, ~512 Mi–1 Gi | if ZAP image cannot pull, run ZAP from the agent host via docker |
| CI engine | **PRESENT but DOWN** | Jenkins 2.568.1 installed (helm), NodePort 30081, replicas 0 | operator must scale Jenkins up; then configure a Kubernetes cloud + pod templates | Jenkins ~1–2 Gi when up | none — CI cannot run until it is up |
| Source repos | **PRESENT but DOWN** | Gitea 1.27.0 installed, replicas 0 | operator must scale Gitea up; then create 3 repos | Gitea ~0.5–1 Gi when up | interim: use the existing GitHub fork `MinaC4/microservices-demo` (operator-directed) |
| Backup / restore | **PRESENT** | Velero 1.18.1 (3 pods) | confirm a backup/schedule covers Vault/Gitea/Harbor/Jenkins before first write | none | operator confirmation required (rule 1.11) |
| SonarQube SAST | **PRESENT (optional)** | SonarQube 2026.4.0 (30090) | optional integration; Semgrep remains the primary SAST | none | Semgrep-only |

## Net new components the engagement may need to install

| Component | Permission flag | Needed for |
|---|---|---|
| Falco + falcosidekick | `may_install_falco` **MISSING** | Phase 9 runtime detection |
| Trivy Operator | `may_install_trivy_operator` **MISSING** | Phase 9 continuous scanning + Phase 11 metrics |
| Loki (or alternative) | not in Section 0 | Phase 11 log aggregation (currently absent) |

Everything else (Harbor, Kyverno, ESO, Vault, Argo CD, Prometheus/Grafana/Jaeger, Velero, SonarQube)
**already exists** and must not be reinstalled (rule 1.12). The engagement adds configuration and
new, namespace-scoped objects only.
