# 07 — GitOps CD (Argo CD)

## Ownership

Argo CD (v3.4.5, pre-existing) owns the `boutique-*` namespaces. **Devtron must not target them.**
A new `AppProject boutique` restricts sources to this repo and destinations to `boutique-*`.

## Layout

```
gitops/
├── components/boutique-hardening/   shared patches (seccomp, SA token, nodeSelector, probe tolerance, ClusterIP)
├── environments/
│   ├── dev/       namespace + ingress + mailpit + digest pins + replicas
│   ├── staging/   same shape, boutique-staging host
│   └── prod/      same + PDBs, manual sync
├── security/      ESO SecretStore/ExternalSecrets + Vault k8s-auth SA (boutique-security)
└── argocd/        AppProject + Applications (dev/staging/prod)
```

Every image reference is pinned **by digest**. Replica counts are declared explicitly so Argo can
enforce them.

## Sync policies

| App | Policy | Notes |
|---|---|---|
| boutique-dev | automated, prune, selfHeal | drift auto-corrected |
| boutique-staging | automated, prune, selfHeal | |
| boutique-prod | **manual** | a human approves every deployment; PDBs present |

## Promotion model

Promotion is **by digest**: an image built and signed by CI is pinned in the target environment's
kustomization; no rebuild, no retag. dev→staging→prod copies the same digest, so "what runs in prod"
is provably identical to "what passed the gates".

## Verified operations (real)

| Operation | Evidence |
|---|---|
| Auto-sync dev from Git | `boutique-dev Synced/Healthy` |
| Manual sync prod | `boutique-prod Synced/Healthy`, ingress 200, PDBs present |
| **Drift self-heal** | scaled `frontend` to 3 out-of-band → Argo reverted to 1 |
| **Rollback via Git revert** | promoted frontend to a CI digest, then reverted; Argo restored the previous digest |
| Three environments from Git | dev/staging/prod all Synced/Healthy, digest-pinned |

## Known issue (root cause of intermittent flakiness)

The **pre-existing** Argo CD `repo-server` runs with very small limits (`cpu=50m`, `memory=64Mi`, 3
replicas) and OOM-restarts frequently. Manifest generation intermittently fails with
`kustomize build ... failed timeout after 1m30s` / `DeadlineExceeded`, which makes apps flap to
`Unknown` and delays syncs. Recommended fix is a **change request** (raise repo-server
CPU/memory); it modifies an existing shared component, so it awaits operator approval.

## Follow-up

- `gitops/security/` is currently applied out-of-band (the `AppProject boutique` covers the env apps).
  Add an Argo Application for it so the ESO objects are GitOps-managed too.
- Enable required status checks for the Jenkins pipeline on `main`/`devsecops` once the job reports a
  stable context.
