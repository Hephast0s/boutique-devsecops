# 01 — Capacity Budget (numeric)

Measured 2026-09-16. "Budget" = allocatable − current usage − 20% headroom reserve.
All figures are real `kubectl top`/node-capacity values; no estimates in the measurement rows.

## 1. Measured baseline

| Node | Alloc CPU | Alloc Mem | Used CPU | Used Mem | 20% CPU reserve | 20% Mem reserve | **Budget CPU** | **Budget Mem** |
|---|---|---|---|---|---|---|---|---|
| mina (cp) | 8.0 | 15.5 Gi | 0.939 | 9.42 Gi | 1.60 | 3.10 Gi | **5.46** | **2.98 Gi** |
| worker-1 | 4.0 | 5.85 Gi | 0.144 | 2.24 Gi | 0.80 | 1.17 Gi | **3.06** | **2.44 Gi** |
| worker-2 | 3.0 | 3.90 Gi | 0.107 | 1.46 Gi | 0.60 | 0.78 Gi | **2.29** | **1.66 Gi** |
| **Total** | **15.0** | **25.25 Gi** | 1.19 | 13.11 Gi | 3.0 | 5.05 Gi | **10.81** | **7.08 Gi** |

Disk: mina `/` has 645 Gi free. **Worker node disk: UNKNOWN** — no host access; `sudo_available` is
unresolved. This must be confirmed before planning large PVs on the workers.

## 2. Demand — Online Boutique (from manifest requests/limits, loadgenerator excluded)

| | CPU req | Mem req | CPU lim | Mem lim |
|---|---|---|---|---|
| dev (1 replica × 11 svc + redis) | 1.17 | 1.09 Gi | 2.33 | 1.98 Gi |
| staging (same shape) | 1.17 | 1.09 Gi | 2.33 | 1.98 Gi |
| prod (same shape) | 1.17 | 1.09 Gi | 2.33 | 1.98 Gi |
| **3 envs total** | **3.51** | **3.27 Gi** | **7.00** | **5.94 Gi** |

Scheduler reserves **requests**, not limits → the binding number is **3.51 CPU / 3.27 Gi**, comfortably
inside the 10.81 / 7.08 budget. Worst-case limits (7.0 CPU / 5.94 Gi) still fit the total budget, but not
on any single node — so scheduling must be spread (see §4).

## 3. Demand — new security/delivery components

| Item | CPU | Mem | Notes |
|---|---|---|---|
| Falco (DaemonSet, 3 nodes) | ~300m total | **~1.5 Gi** (512 Mi/node) | not yet installed — permission MISSING |
| Trivy Operator (namespaced `boutique-*`) | ~100m | 256 Mi | not yet installed — permission MISSING |
| Loki (if added for logs) | ~100m | 300–500 Mi + storage | currently ABSENT — needs decision |
| ZAP Job (staging, **on-demand**) | 500m | 512 Mi–1 Gi | transient |
| Windows/CI: Jenkins controller (already installed, DOWN) | — | 1–2 Gi when up | existing component, off |
| Gitea (already installed, DOWN) | — | 0.5–1 Gi when up | existing component, off |
| Jenkins build agent — **adservice peak** | 1.0 | **2.0 Gi** | Gradle/JDK 25 — memory peak |
| Jenkins build agent — cartservice peak | 0.5 | 1.5 Gi | .NET trimmed publish |
| Jenkins build agent — Go/Node/Python | 0.5 | 512 Mi–1 Gi | per run |

Kyverno, ESO, Vault, Harbor, Argo CD, Prometheus, Grafana, Jaeger, SonarQube, Velero are **already
running** and already counted in the measured usage — they cost nothing new.

## 4. Verdict (explicit)

**Fits:**
- dev + staging + prod, one replica each, spread across the two workers (`node-type=worker`).
- Trivy Operator on mina (256 Mi against 2.98 Gi budget).
- Falco DaemonSet — **accept**, but worker-2 becomes the tight node (1.66 Gi budget − 512 Mi ≈ 1.15 Gi left).
- CI agents scheduled on **mina** (largest budget), serialized for the two memory-peak builds.

**On-demand only (never standing):**
- `loadgenerator` (300m/256Mi req, 500m/512Mi lim) — Phase 10 load test as a timed Job.
- ZAP baseline/full scans against staging — Phase 10.

**Declined / substituted:**
- **Nexus caching — not available.** Substituted with PVC-backed toolchain caches + Harbor as the
  runtime registry mirror. Cold builds will be slower; documented in `01-capability-matrix.md`.
- **Loki — absent.** Centralized log aggregation cannot be delivered without installing a new component.
  Falls back to Falco→Alertmanager webhook + Jenkins-archived reports, unless the operator approves Loki.
- **HPA** — not added: with replicas=1 and limited headroom, autoscaling is not meaningful here; PDBs
  (staging/prod) are the chosen availability control instead.
- **shoppingassistantservice** — never deployed (GCP dependency).

## 5. Scheduling plan (no node label/taint changes — rule 1.1)

- **mina (control-plane):** CI agents, Jenkins controller, Trivy Operator, and existing platform stack.
  High-memory builds (adservice, cartservice) pinned here via pod-template nodeSelector
  `kubernetes.io/hostname=mina`; serialize them to avoid OOM.
- **worker-1 / worker-2:** boutique dev/staging/prod via nodeSelector `node-type=worker`, with
  `topologySpreadConstraints` so replicas of the same env are not co-located when scaled beyond 1.
- No node labels or taints are added; only existing labels (`node-type=worker`, `kubernetes.io/hostname`) are used.

## 6. Jenkins build-agent memory plan

- Pod templates set **requests = 50% of limit** to improve packing; limits: go/node/python 1 Gi,
  dotnet 1.5 Gi, java-gradle 2 Gi.
- A Jenkins `lock` named `heavy-build` serializes adservice and cartservice builds.
- Concurrency cap on the Kubernetes cloud (≤3 agents) to stay within mina's budget.
