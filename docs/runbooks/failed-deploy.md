# Runbook — Failed deploy / rollout

1. **Detect:** Argo app not `Synced/Healthy`; Prometheus `BoutiqueDeploymentReplicasMismatch` or
   `BoutiquePodNotReady`.
2. **Triage:**
   - `kubectl -n boutique-<env> get deploy,pods`
   - `kubectl -n boutique-<env> describe pod <pod>` — events (ImagePull, probe, policy denial).
   - `kubectl -n boutique-<env> logs deploy/<svc> --tail=50`
3. **If a policy denied it:** the message names the `boutique-*` policy; fix the manifest (digest, registry,
   limits, probes, securityContext) and re-commit.
4. **If the image is bad:** roll back (see `runbooks/rollback.md`).
5. **Verify:** `bash tests/smoke/smoke.sh http://boutique-<env>.192.168.1.8.nip.io`; Argo `Synced/Healthy`.
6. **Record:** add a line to `docs/ISSUES.md` (cause + fix).
