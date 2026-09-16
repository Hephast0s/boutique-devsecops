# CHANGE_REQUESTS

Requests that require the operator's approval or action because they would modify a component this
engagement does not own (rule 1.1) or because a Section 0 permission is missing.

## CR-001 — Scale Jenkins back up (BLOCKING for Phases 2 & 4)
- **Observed:** `kubectl -n jenkins get sts jenkins` → `replicas=0`; pod list empty; NodePort 30081 closed.
- **Need:** Jenkins running so CI can be configured.
- **Proposed command (operator, or approve me to run):**
  `kubectl -n jenkins scale statefulset jenkins --replicas=1`
- **Blast radius:** starts the existing Jenkins controller (~1–2 Gi on its scheduled node). No config change.
- **Rollback:** `kubectl -n jenkins scale statefulset jenkins --replicas=0`
- **Risk:** resource pressure if scheduled on a node without headroom; prefer node `mina`.

## CR-002 — Scale Gitea back up (BLOCKING for Phase 2)
- **Observed:** `gitea`, `gitea-postgresql-ha-pgpool` deployments and both statefulsets → `replicas=0`.
- **Need:** Gitea running to create `boutique-app` / `boutique-gitops` / `boutique-jenkins-library`.
- **Proposed commands:** `kubectl -n gitea scale deploy/gitea --replicas=1` (+ the pgpool/postgresql/valkey
  backends as needed per the chart's original replica counts — operator knows the intended values).
- **Blast radius:** starts the existing Gitea stack (~1–2 Gi). No config change.
- **Rollback:** scale back to 0.
- **Interim:** until then, pushes go to the GitHub fork `MinaC4/microservices-demo` (operator-directed).

## CR-003 — Install permissions still unanswered (Section 0)
- `may_install_falco` — needed for Phase 9 runtime detection (est. ~512 Mi × 3 nodes).
- `may_install_trivy_operator` — needed for Phase 9 continuous scanning + Phase 11 metrics (~256 Mi).
- Loki is **absent**; Phase 11 log aggregation needs a decision (install Loki vs. alternative).

## CR-004 — Local tool installs (Section 0)
- `may_install_local_tools` unanswered. Missing locally: syft, gitleaks, semgrep, hadolint, kustomize,
  dotnet, java. Interim plan: run them ephemerally via `docker run` (no host install). Confirm this is acceptable.

## CR-005 — Vault access and scoped mount
- Need a Vault **token/AppRole** with permission to create a KV v2 mount/path `boutique/` and a policy.
  Without it Phase 6 is blocked. `vault_may_create_mount` unanswered.

## CR-006 — Harbor robot credentials
- Need permission to create project `boutique` and two robot accounts (push-only for Jenkins,
  pull-only for the cluster). No Harbor auth token was provided.

## CR-007 — Jenkins API token + agent setup
- For Phase 4: a Jenkins API token to create jobs/credentials, and confirmation that a Kubernetes cloud
  may be configured (or one already exists that we can add pod templates to).

## CR-008 — Gitea admin token
- For Phase 2: to create the three repos and set branch protection.

## CR-009 — Pre-engagement backups (rule 1.11)
- Velero 1.18.1 **is installed and running**. Please confirm that a backup (Velero schedule or manual)
  covering **Vault, Gitea, Harbor, and `JENKINS_HOME`** exists and is current before the first write.
  Taking these backups is the operator's action, not the agent's.

## CR-010 — Remote deviation record
- Operator instructed "push every change to the repo". Gitea is down, so pushes go to the GitHub fork
  `MinaC4/microservices-demo` (not the Google upstream). Recorded as an accepted deviation in
  `CHANGE_LOG.md`. Confirm this remains the intent once Gitea is restored.
