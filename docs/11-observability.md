# 11 — Observability and KPIs

## What is wired

- **Grafana dashboard** `Boutique — Runtime & Health` (uid `boutique-runtime`) delivered as a ConfigMap
  with `grafana_dashboard: "1"`; the Grafana sidecar imported it automatically (verified via the Grafana
  API: `api/search?query=Boutique` → the dashboard).
- **PrometheusRule** `boutique-alerts` (label `release: prometheus`) loaded by the existing Prometheus
  (verified: group `boutique.rules` present in `/api/v1/rules`). Alerts:
  - `BoutiqueDeploymentReplicasMismatch`
  - `BoutiquePodCrashLooping`
  - `BoutiquePodNotReady`

## Metric dictionary (data-backed)

| Panel | PromQL | Source |
|---|---|---|
| Pods not ready | `sum(kube_pod_status_ready{namespace=~"boutique-.*",condition="true"} == 0)` | kube-state-metrics |
| Deployment replica shortfall | `kube_deployment_spec_replicas - kube_deployment_status_replicas_available` | kube-state-metrics |
| Container restarts (1h) | `increase(kube_pod_container_status_restarts_total[1h])` | kube-state-metrics |
| CPU by pod | `sum(rate(container_cpu_usage_seconds_total{...}[5m])) by (pod)` | cAdvisor |
| Memory by pod | `sum(container_memory_working_set_bytes{...}) by (pod)` | cAdvisor |

Data confirmed present: `kube_pod_status_ready` = 204 series, `container_memory_working_set_bytes` = 102,
`kube_deployment_spec_replicas` = 68.

## Why not the full 5 dashboards

The target design lists five dashboards (delivery/DORA, pipeline health, supply chain, vulnerability
posture, application/runtime). Three depend on data sources that do **not exist** in this cluster:

| Dashboard | Blocker |
|---|---|
| Delivery / DORA | no Git/Jenkins → Prometheus integration; would need a metrics exporter or the Jenkins Prometheus plugin |
| Pipeline health | same (Jenkins metrics exporter absent) |
| Supply chain (signed vs total, attestation) | no exporter for signature coverage; could be added later |
| Vulnerability posture | **Trivy Operator not installed** (CR-003) — no per-workload CVE metrics |
| Application/runtime | delivered here (kube-state-metrics + cAdvisor) |

Rather than ship dashboards with no data, the data-backed dashboard is delivered and the missing ones are
recorded with their exact prerequisite. This is honest and actionable.

## Alerts routing

The existing Alertmanager was **not modified** (it is shared infrastructure). Adding a receiver for these
alerts is a change request (CR-ALERT-1) if the operator wants notifications. Until then the rules are
visible in Prometheus/Grafana with the cluster's default Alertmanager behaviour.

## Log aggregation

**Loki is not installed** (confirmed). Application and Falco logs are therefore not centrally aggregated.
This is recorded as a gap; a new Loki install is subject to the 4 GiB cap review.

## Honest limitations

- Only one dashboard with real data; three others blocked on missing exporters/sources.
- No alert was proven to **fire** end-to-end (would require holding a failure past `for: 5m`; Argo
  self-heals faster). Rule loading and data presence are proven instead.
- No log aggregation, no trace dashboards (Jaeger exists but the app has tracing disabled by default).
