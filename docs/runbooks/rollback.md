# Runbook — Rollback

Rollback is a **Git operation**; Argo CD reconciles the cluster to the previous commit.

1. Identify the last good revision:
   `git log --oneline origin/devsecops -- gitops/environments/prod/`
2. Revert the offending commit:
   `git revert <sha>` → PR → merge to `devsecops` (protected: needs review + signed).
3. **dev/staging** (automated): Argo syncs automatically.
   **prod** (manual): trigger sync:
   ```
   kubectl -n argocd patch application boutique-prod --type merge \
     -p '{"operation":{"initiatedBy":{"username":"operator"},"sync":{"revision":"devsecops"}}}'
   ```
4. Verify the running digest:
   `kubectl -n boutique-<env> get deploy frontend -o jsonpath='{.spec.template.spec.containers[0].image}'`
5. Verify: `bash tests/smoke/smoke.sh http://boutique-<env>.192.168.1.8.nip.io`.
6. If Argo is wedged: `kubectl -n argocd annotate application boutique-<env> argocd.argoproj.io/refresh=hard --overwrite`.

Demonstrated during the engagement (digest revert, Argo restored the previous digest).
