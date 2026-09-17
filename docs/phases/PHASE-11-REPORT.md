# PHASE-11 REPORT — Observability and DevSecOps KPIs

Date: 2026-09-16 · Branch: `phase-11-observability` · New objects: 1 Grafana dashboard ConfigMap,
1 PrometheusRule. Existing objects changed: none.

## 1. What was done

- Delivered a data-backed Grafana dashboard (`Boutique — Runtime & Health`) via the Grafana sidecar.
- Added 3 Prometheus alerts, loaded by the existing Prometheus (verified).
- Confirmed the underlying metric series exist (kube-state-metrics + cAdvisor).
- Documented the dashboards that cannot be built because their data sources are absent.

## 2. Evidence

```
Grafana API:  api/search?query=Boutique -> uid "boutique-runtime" (imported)
Prometheus:   /api/v1/rules -> group boutique.rules [BoutiqueDeploymentReplicasMismatch,
              BoutiquePodCrashLooping, BoutiquePodNotReady]
Data:         kube_pod_status_ready=204 ; container_memory_working_set_bytes=102 ; kube_deployment_spec_replicas=68
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Five dashboards with real data | ❌ → **1** data-backed dashboard; others blocked (no Jenkins/Git/Trivy Operator/Loki data sources) |
| ≥1 alert proven to fire end to end | ◑ rules loaded + data present; firing not demonstrated (Argo self-heals < 5m) |
| Every metric traceable to its source | ✅ (metric dictionary in `docs/11-observability.md`) |

## 4. Real findings

- Prometheus selects rules by `release: prometheus`; `ruleNamespaceSelector={}` matches all namespaces.
- Grafana sidecar watches `grafana_dashboard=1` in **all** namespaces (NAMESPACE=ALL).
- Label names in Prometheus rules cannot contain hyphens → used `part_of`.

## 5. Next

Phase 12 (Backstage catalog) and Phase 13 (documentation/evidence packaging).
