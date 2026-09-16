# PHASE-1 REPORT — Infrastructure Discovery (read-only)

Date: 2026-09-16 · Context: `default` (k3s v1.36.2+k3s1) · Existing objects changed: **none**
One sanctioned temporary write (`boutique-preflight`), proven removed.

## 1. Commands run (read verbs; one announced exception)

```
kubectl config current-context / get-contexts / config view --minify
kubectl version -o json | jq .serverVersion.gitVersion ; kubectl get nodes -o wide
kubectl describe nodes | grep 'Allocated resources' ; kubectl top nodes ; kubectl top pods -A --sort-by=memory
kubectl get ns ; get pods -A ; get deploy,sts,ds -A ; get svc -A ; get ingress,ingressclass -A
kubectl get sc,pv,pvc -A ; get netpol -A ; get clusterpolicies -A ; get applications,appprojects -A
kubectl get crd ; get validatingwebhookconfigurations,mutatingwebhookconfigurations
kubectl get secretstores,externalsecrets -A ; helm list -A ; helm list -A -o yaml
kubectl -n <gitea|jenkins|harbor|vault|argocd|devtroncd> get ... -o jsonpath=...
ps -ef | grep k3s ; systemctl show k3s -p ExecStart
curl sys/health (Vault) ; curl api/v2.0/health + projects (Harbor) ; curl grafana/argocd health
df -h / ; free -g ; nproc
[WRITE] kubectl create ns boutique-preflight ; run pod curlimages/curl ; exec curl matrix ; delete ns
```

## 2. Real output highlights

```
server v1.36.2+k3s1 ; nodes 3: mina(cp,8c/15.5Gi) worker-1(4c/5.85Gi) worker-2(3c/3.9Gi)
top: mina 939m/9420Mi(62%)  worker-1 144m/2238Mi(39%)  worker-2 107m/1458Mi(38%)
namespaces 28 ; no boutique-* ; Harbor projects: apps, hephastos, library (no boutique)
kyverno v1.18.2 (8 ClusterPolicies, ALL scoped namespaces:["hephastos"], 7 Enforce/1 Audit)
external-secrets v2.9.0 (pre-existing SecretStore/vault = InvalidProviderConfig)
vault 2.0.3 initialized=true sealed=false ; harbor 2.15.1 healthy (trivy on)
argocd v3.4.5 (Application hephastos-dashboard, automated prune+selfHeal) ; devtron 2.2.0 also present
prometheus v0.92.1 + grafana + jaeger + otel-collector present ; Loki ABSENT ; Nexus ABSENT
jenkins sts replicas=0 (DOWN) ; gitea deployments replicas=0 (DOWN) ; velero 1.18.1 running
traefik default IngressClass ; hosts *.192.168.1.8.nip.io ; no cert-manager (HTTP only)
k3s server: no --disable-network-policy  → netpol controller embedded (PROVE in Phase 9)
egress in-cluster: docker.io/ghcr/gcr/quay 401(reachable), mcr 200, npm/pypi/maven/go/nuget 200,
                   harbor 200, vault 200, CoreDNS 10.43.0.10 resolves
cleanup: kubectl get ns boutique-preflight -> NotFound (0 pods)
```

## 3. Deliverables

| File | Content |
|---|---|
| `docs/01-agent-capabilities.md` | toolchain + versions, execution model, egress results |
| `docs/01-infrastructure-inventory.md` | nodes, namespaces, components, ingress/DNS/storage, CRDs, GitOps authority |
| `docs/01-capability-matrix.md` | present/absent matrix + net-new installs + fallbacks |
| `docs/01-capacity-budget.md` | numeric budget + verdict + scheduling + CI memory plan |
| `docs/01-ADR-0001-platform-choices.md` | GitOps, registry, signing, policy, caching, secrets, interim remote |
| `docs/CHANGE_REQUESTS.md` | 10 requests needing operator action/approval |
| `docs/evidence/pre-engagement/` | `all.yaml` (86 994 lines), `cluster-scoped.yaml` (270 705), `storage.yaml`, `helm-releases.yaml`, `kyverno-policies.yaml`, `namespaces.txt` |

## 4. Decisions resolved

- Execution model: present binaries direct + missing tools via ephemeral `docker run`; CI on Jenkins agents.
- GitOps controller: **Argo CD** owns `boutique-*` (Devtron excluded).
- Registry: Harbor project `boutique` (HTTP; CA trust would be a node-level change request).
- Signing: key-based cosign, private key in Vault.
- Policy: new `boutique-*`-scoped Kyverno policies; existing `hephastos` policies untouched.
- Caching: Nexus absent → PVC caches + Harbor mirror.
- Remote: push to GitHub fork (Gitea down), operator-directed deviation.

## 5. Definition of Done

| Item | Status | Evidence |
|---|---|---|
| Every command a read verb; preflight exception proven cleaned up | ✅ | §1, §2 cleanup line; CHANGE_LOG |
| Every Section 0 field resolved/discovered/blocked | ✅ | `OPERATOR_ANSWERS.md`, `01-infrastructure-inventory.md` §9 |
| Agent execution model decided | ✅ | `01-agent-capabilities.md` §2 |
| Egress tested with real output; Nexus gap escalated | ✅ | `01-agent-capabilities.md` §3–4 |
| NetworkPolicy enforcement answered definitively | ⏸ | k3s has netpol controller enabled (no disable flag); **empirical proof deferred to Phase 9** as the prompt requires |
| Capacity verdict numeric | ✅ | `01-capacity-budget.md` §4 |
| Pre-engagement restore point exists | ✅ | `docs/evidence/pre-engagement/` |
| Stateful backups confirmed by operator | ⏸ BLOCKED | CR-009; Velero present, confirmation pending |
| No existing object modified | ✅ | only `boutique-preflight` created+deleted |

## 6. Blockers (see `CHANGE_REQUESTS.md`)

1. **CR-001 Jenkins down** (replicas 0) — blocks Phases 2 & 4.
2. **CR-002 Gitea down** (replicas 0) — blocks Phase 2; interim GitHub push accepted.
3. **CR-003/004** install permissions (Falco, Trivy Operator, Loki) + local tool installs unanswered.
4. **CR-005/006/007/008** Vault, Harbor, Jenkins, Gitea credentials missing.
5. **CR-009** stateful backups not yet confirmed.

## 7. Cost

Wall-clock ≈ 40 min. Cluster resources: one pod for ~30 s. No writes retained.
