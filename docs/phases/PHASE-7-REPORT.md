# PHASE-7 REPORT — GitOps CD (dev → staging → prod)

Date: 2026-09-16 · Branch(es): `phase-7-*` · New objects: AppProject `boutique`, Applications
`boutique-dev|staging|prod`, `boutique-staging`/`boutique-prod` namespaces, Mailpit, ESO `smtp-eso`.
Existing objects changed: none.

## 1. What was done

- Refactored overlays: shared `boutique-hardening` component; `dev`/`staging`/`prod` environments with
  digest-pinned images, explicit replica counts, ingress, and (prod) PDBs.
- Created `AppProject boutique` (sources = this repo; destinations = `boutique-*`) and three
  Applications. dev/staging automated (prune+selfHeal); **prod manual**.
- Demonstrated drift self-heal and a Git-revert rollback.
- Deployed all three environments; verified reachability.

## 2. Evidence

```
Argo:  boutique-dev Synced/Healthy ; boutique-staging Synced/Healthy ; boutique-prod Synced/Healthy
HTTP:  dev 200 ; prod 200 ; staging 200
Drift: frontend scaled 1->3 out-of-band  =>  Argo reverted to 1
Rollback: promoted frontend to CI digest, then `git revert` => Argo restored sha256:c06df08e...
Promotion: by digest (no rebuild/retag); prod requires manual sync
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Three environments running from Git | ✅ dev/staging/prod |
| Every image reference is a digest | ✅ (11 images per env) |
| Drift self-heal demonstrated (dev) | ✅ |
| Rollback via Git revert (<5 min) | ✅ (a revert commit; applied on next Argo reconcile) |
| prod manual sync + PDBs | ✅ |
| Only one GitOps controller owns `boutique-*` | ✅ (Argo CD; Devtron untouched) |

## 4. Issues encountered (real)

1. **Staging/prod initially Unknown** — Argo repo-server could not find the paths because the overlays
   were not yet committed to `devsecops`; resolved by merging (PR #7).
2. **`replicas` not enforced** — Argo cannot enforce fields absent from Git; declared replica counts
   explicitly (PR #8).
3. **Mailpit broke manifest generation** — the shared hardening component adds `seccompProfile` to pod
   `securityContext`, which mailpit lacked; added a pod securityContext (PR #11).
4. **prod sync timeout** — repo-server resource starvation; a new revision cleared the cached error and
   the sync succeeded. Root cause raised as a change request (repo-server resources).

## 5. Cost

Argo CD + existing platform only; no new standing components except Mailpit (dev, ~32Mi) and one
emailservice rebuild. Within the 4 GiB cap.

## 6. Next

Phase 8 — Kyverno admission control scoped to `boutique-*` (verifyImages + restricted set), with the
cosign public key from Phase 5.
