# ROLLBACK — ordered teardown of this engagement

Current status: **nothing to roll back yet.** Phase 0 made no cluster or remote changes.

Principles:
- Teardown must only ever delete objects listed in `docs/CHANGE_LOG.md`.
- Never delete or modify anything this engagement did not create.
- Order is reverse-dependency: workloads → policies → GitOps apps → namespaces → registry/secrets/repos.

## Planned teardown (to be filled as objects are created)

```bash
# Phase 7 — stop GitOps reconciliation first (prevents re-creation)
# argocd app delete <app> --cascade=false     # or Devtron equivalent — ONLY boutique-* apps
# kubectl -n <gitops-ns> delete application <boutique-app> -l app.kubernetes.io/part-of=online-boutique

# Phase 8 — remove our Kyverno policies (never touch pre-existing policies)
# kubectl delete -f boutique-gitops/policies/ --ignore-not-found

# Phase 9 — runtime/scanning
# helm uninstall <falco-release> -n <ns>          # ONLY the release we installed
# kubectl delete -f trivy-operator/ -n boutique-security --ignore-not-found

# Phase 3/6 — workloads then namespaces
# kubectl delete namespace boutique-dev boutique-staging boutique-prod boutique-security --ignore-not-found

# Phase 6 — scoped Vault path (operator-approved)
# vault kv metadata delete boutique/ ; vault policy delete boutique-*

# Phase 5 — Harbor project
# harbor: delete project "boutique" (UI/API) — only the project we created

# Phase 2 — Gitea repos
# gitea: delete repos boutique-app, boutique-gitops, boutique-jenkins-library
```

## Baseline restore point

Read-only export of the pre-engagement cluster state is taken in Phase 1 to
`docs/evidence/pre-engagement/` (rule 1.11). Stateful backups (Vault, Gitea, Harbor, `JENKINS_HOME`)
are the **operator's** action and must be confirmed before the first write.
