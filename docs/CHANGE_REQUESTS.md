# CHANGE_REQUESTS

Requests that require the operator's approval or action because they would modify a component this
engagement does not own (rule 1.1) or because a Section 0 permission is missing.

## CR-001 — Jenkins — RESOLVED (scaled up, operator-authorized)
Operator authorized the scale command on 2026-09-16. Executed:
`kubectl -n jenkins scale statefulset jenkins --replicas=1` → pod `jenkins-0` 3/3 Running on `mina`.
Jenkins 2.568.1-jdk21; anonymous API returns **403** (no anonymous read). Credentials exist in the
`jenkins` secret (`jenkins-admin-user`/`jenkins-admin-password`) — value not printed.
Still needed for Phase 4: a Jenkins **API token** or admin credentials (CR-007).

## CR-002 — Gitea — RESOLVED (will not be used)
Operator decision 2026-09-16: **Gitea will not be started.** All Git work happens on **GitHub**.
Phase 2 therefore targets GitHub repos + branch protection, not Gitea. No Gitea action needed.

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

## CR-010 — RESOLVED — GitHub is the source of truth
Operator decision 2026-09-16: the work is on **GitHub**, not Gitea. Pushes go to
`github.com/MinaC4/microservices-demo` (operator's fork — not the Google upstream) and to new GitHub
repos for GitOps/library. The Gitea-first plan in the original engagement is superseded.

## CR-011 — Resource cap
Operator directive 2026-09-16: total RAM added by this engagement must stay **≤ 4 GiB**
(tooling + any new cluster components). This constrains Falco + Trivy Operator + Loki + ZAP to fit
within 4 GiB combined; Loki is the first thing to drop if the cap is hit.

## JS-CR-1 — Jenkins authorization is `loggedInUsersCanDoAnything` (High)
Any authenticated user has full admin. Recommend installing `matrix-auth`/`role-strategy` and defining a
least-privilege matrix. Shared config → operator decision. Details: `docs/04-jenkins-security-review.md`.

## JS-CR-2 — Default Jenkins agent template mounts the host Docker socket (Medium)
`/var/run/docker.sock` + `/usr/bin/docker` are hostPath volumes in the default agent template. Any job
using it can control the node. Recommend removing them. Our pipeline does not use that template.

## JS-CR-3 — `JENKINS_HOME` is a hostPath tied to node `mina` (Medium)
Recommend migrating to a PVC and including it in Velero backups (ties to CR-009).

## CR-KYVERNO-1 — Kyverno cannot verify signatures from the HTTP/private-IP Harbor (Medium)
**Symptom:** `boutique-verify-images` (Audit) reports `invalid realm in www-authenticate: realm host
"192.168.1.8" is a private or link-local address`; Kyverno/go-containerregistry refuses to follow an auth
realm on a private IP. Enforcing the policy now would block every legitimate pod.
**Options:**
1. Point Harbor's registry token realm / external URL at a hostname (e.g. `harbor.192.168.1.8.nip.io`)
   and supply Kyverno registry credentials; re-test. (Harbor config change.)
2. Configure Kyverno with a registry credential (`imageRegistryCredentials`) so it does not negotiate the
   realm. (Kyverno config / new secret in the kyverno namespace.)
3. Serve Harbor with TLS from a trusted CA (larger change).
**Decision needed:** which option, and approval to modify the shared component.

## CR-ARGO-1 — Argo CD `repo-server` is under-resourced (Medium)
`limits: cpu=50m, memory=64Mi`, 3 replicas, frequent OOM restarts → intermittent
`kustomize build ... failed timeout after 1m30s` / `DeadlineExceeded`, apps flap to `Unknown`, syncs
delay. Recommend raising CPU/memory (single shared component). Command in `docs/07-gitops.md`.
