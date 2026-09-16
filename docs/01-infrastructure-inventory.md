# 01 — Infrastructure Inventory (read-only)

Captured 2026-09-16 from context `default` on k3s v1.36.2+k3s1. Raw restore-point export is in
`docs/evidence/pre-engagement/`. Everything below is from `kubectl get/describe/top` and `helm list`.

## 1. Nodes

| Node | Role | CPU | Memory | Disk free | OS | Node IP | Labels | Taints |
|---|---|---|---|---|---|---|---|---|
| mina | control-plane | 8 | 15.5 Gi | ~645 Gi (`/`) | Ubuntu 26.04.1 | 192.168.1.8 | `node-role.kubernetes.io/control-plane=true`, `workload=tools` | none |
| worker-1 | worker | 4 | 5.85 Gi | UNKNOWN (no host access) | Ubuntu 24.04.4 | 10.1.211.122 | `node-type=worker`, `workload=tools` | none |
| worker-2 | worker | 3 | 3.90 Gi | UNKNOWN (no host access) | Ubuntu 24.04.4 | 10.1.211.202 | `node-type=worker`, `workload=tools` | none |

- Runtime: `containerd://2.3.2-k3s2` on all three.
- **The control-plane is schedulable** (no NoSchedule taint) — important for the capacity plan.
- **Two workers + control-plane = 3 nodes**, correcting the operator's initial "2 nodes".

## 2. Current utilization (`kubectl top`)

| Node | CPU | Memory | Mem % |
|---|---|---|---|
| mina | 939m | 9420 Mi | 62% |
| worker-1 | 144m | 2238 Mi | 39% |
| worker-2 | 107m | 1458 Mi | 38% |

Host view (`free -g` on mina): total 14, used 9, available 5, swap 3 (2 used).
Top memory pods: `prometheus-...-0` 904 Mi, `argocd-application-controller-0` 505 Mi, `prometheus-grafana` 335 Mi.

## 3. Namespaces (28)

`argo`, `argocd`, `backstage`, `default`, `devtron-cd`, `devtron-ci`, `devtron-demo`, `devtroncd`,
`external-secrets`, `gitea`, `harbor`, `hephastos`, `hephastos-app-demo-api-dev`,
`hephastos-app-m-dev`, `hephastos-app-prod-demo-production`, `jenkins`, `kube-node-lease`,
`kube-public`, `kube-system`, `kubernetes-dashboard`, `kyverno`, `monitoring`, `observability`,
`semaphore`, `sonarqube`, `tools`, `vault`, `velero`.

**No `boutique-*` namespace exists** (name-collision check: clean) and no Harbor project `boutique`.

## 4. Platform components (from `helm list -A`)

| Component | Version | Namespace | Access | State |
|---|---|---|---|---|
| kyverno | v1.18.2 | kyverno | kyverno-ui NodePort 30091 | Running, **8 ClusterPolicies** |
| policy-reporter | 3.9.0 | kyverno | UI | Running |
| external-secrets | v2.9.0 | external-secrets | webhooks present | Running |
| vault | 2.0.3 | vault | NodePort 30086 (HTTP health 200) | initialized, **unsealed** |
| harbor | 2.15.1 | harbor | ingress `harbor.192.168.1.8.nip.io`, core NodePort 30082 | healthy, **Trivy scanner on** |
| gitea | 1.27.0 | gitea | NodePort 30080 | **DOWN — replicas 0** |
| jenkins | 2.568.1 | jenkins | NodePort 30081 | **DOWN — replicas 0** |
| argo-cd | v3.4.5 | argocd | NodePort 30085 | Running, 1 Application |
| devtron | 2.2.0 | devtroncd | ingress `devtron.192.168.1.8.nip.io` | Running |
| argo-rollouts | v1.9.1 | observability | ClusterIP | Running (no Rollout objects) |
| kube-prometheus-stack | v0.92.1 | monitoring | Grafana 30084, Prometheus 30083 | Running |
| minio | RELEASE.2024-… | observability | console 30095 | Running |
| otel-collector | 0.158.0 | observability | ClusterIP | Running |
| jaeger | (obs) | observability | query 30094 | Running — **tracing backend exists** |
| sonarqube | 2026.4.0 | sonarqube | NodePort 30090 | Running |
| velero | 1.18.1 | velero | — | Running (3 pods) — **backup tooling present** |
| traefik | v3.7.1 (+CRD) | kube-system | LoadBalancer 80/443, **default IngressClass** | Running |
| descheduler | 0.36.0 | kube-system | — | periodic Completed jobs |
| backstage | (portal) | backstage | ingress `backstage.192.168.1.8.nip.io` | Running |
| semaphore | — | semaphore | NodePort 30092 | Running |

**Absent:** Loki (no log aggregation), Nexus (no artifact proxy), cert-manager (no TLS issuer),
Trivy Operator, Falco.

## 5. Ingress, DNS, storage

- IngressClass: **traefik (default)**. Existing hosts follow `<name>.192.168.1.8.nip.io`; all plain HTTP (port 80).
- No `cert-manager`/`ClusterIssuer`/`Certificate` objects → **TLS is HTTP-only** on this cluster.
  Consequence: Harbor pulls must be over HTTP or with a trusted CA; trusting a self-signed CA is a
  node-level change → change request if needed (Harbor ingress is HTTP today).
- StorageClass: `local-path` (default, `rancher.io/local-path`), `WaitForFirstConsumer`, reclaim `Delete`.
- Cluster DNS: CoreDNS `kube-dns` at `10.43.0.10`.

## 6. Admission, CRDs and webhooks (pre-existing — do not modify)

- Kyverno webhooks: 5 validating + 3 mutating (incl. `kyverno-verify-mutating-webhook-cfg`).
- ESO: `externalsecret-validate`, `secretstore-validate`.
- Prometheus admission + `vault-agent-injector` mutating webhook.
- Kyverno **8 ClusterPolicies, all scoped to the `hephastos` namespace only**:
  `add-default-resources`, `block-host-access`, `block-privileged-containers`,
  `drop-all-linux-capabilities`, `require-image-tag`, `require-namespace-label` (Audit),
  `require-non-root-user`, `require-read-only-root-filesystem`.
  → They do **not** touch `boutique-*`; we add new `boutique-*`-scoped policies and modify none.
- `imagevalidatingpolicies.policies.kyverno.io` CRD is present → Kyverno supports image verification.
- `policyexceptions` CRD present → per-workload exceptions are possible.
- ESO `SecretStore/vault` in `external-secrets` reports **InvalidProviderConfig** (pre-existing);
  our design will use our own `SecretStore` in `boutique-security` rather than repairing this one.

## 7. NetworkPolicy enforcement

- k3s server process: `/usr/local/bin/k3s server` with **no `--disable-network-policy`** flag.
  k3s ships the embedded kube-router network-policy controller enabled by default → NetworkPolicy
  **is expected to be enforced**. This will be **proven empirically in Phase 9** (prompt requires proof,
  not documentation).
- 12 existing NetworkPolicies (argocd×7, gitea×3, `hephastos-app-*` isolation×2).

## 8. GitOps authority

Two GitOps-capable controllers exist. Evidence of active use:
- **Argo CD v3.4.5** manages `Application/hephastos-dashboard` → repo `github.com/MinaC4/Odysseus.git`,
  path `charts/hephastos`, destination namespace `hephastos`, `syncPolicy.automated { prune:true, selfHeal:true }`.
- Devtron 2.2.0 is installed and running but no boutique/hephastos application is visible via its CRDs.

Recommendation (see ADR-0001): **Argo CD is the GitOps controller** for `boutique-*`; Devtron must not be
pointed at these namespaces.

## 9. Registry / secrets unknowns (blocked)

| Need | Status |
|---|---|
| Harbor project list | ✅ `apps`, `hephastos`, `library` (all public); no `boutique` |
| Harbor credentials/robot for push | ❌ not provided (Harbor API write needs auth) |
| Gitea repos + org | ❌ blocked — Gitea is down (replicas 0) |
| Vault mounts/auth/token | ❌ blocked — needs a token (`/v1/sys/mounts` → 403) |
| Jenkins jobs/plugins/agent config | ❌ blocked — Jenkins is down (replicas 0) |
| Grafana/Prometheus datasource & scrape config | partial — Grafana API 200 but needs auth to inspect |
| Nexus repositories | ❌ Nexus not installed |
