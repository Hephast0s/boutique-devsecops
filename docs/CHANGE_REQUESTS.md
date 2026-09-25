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
**Attempted 2026-09-17:** the registry realm is `http://192.168.1.8:30082/service/token`. Adding
`imageRegistryCredentials.allowInsecureRegistry: true` was accepted by Kyverno but **did not help** — the
realm check lives in the auth transport, not the TLS config. The only viable fixes are changing the
registry's realm host (Harbor config) or serving it over TLS with a trusted CA.

## CR-ARGO-1 — Argo CD `repo-server` is under-resourced (Medium)`limits: cpu=50m, memory=64Mi`, 3 replicas, frequent OOM restarts → intermittent
`kustomize build ... failed timeout after 1m30s` / `DeadlineExceeded`, apps flap to `Unknown`, syncs
delay. Recommend raising CPU/memory (single shared component). Command in `docs/07-gitops.md`.

## CR-WEB-1 — Register the catalog in Backstage (Low)
Need permission/token to add a new **location** (`catalog-info.yaml`) to the existing Backstage portal
without editing shared config. Catalog files are delivered; registration pending.

## CR-ALERT-1 — Add an Alertmanager receiver for `boutique-alerts` (Low)
The 3 boutique alerts load into the existing Prometheus. Notifications require a receiver in the existing
Alertmanager (shared config). Until then the alerts are visible in Prometheus/Grafana only.

## CR-006b — Harbor pull robot for the cluster (Low)
The project `boutique` is public; a dedicated pull-only robot is recommended so the cluster pulls
authenticated. Creation needs a Harbor token (CR-006).

## CR-JENKINS-METRICS-1 — Install the Jenkins Prometheus plugin (Low)
The delivery/DORA and pipeline-health Grafana dashboards need Jenkins metrics. The `prometheus` plugin is
**not installed** (verified: `/prometheus/` → 404). Installing it modifies the Jenkins plugin set and
requires a restart (shared config) → needs approval. Endpoint would then be scraped via a ServiceMonitor.

## CR-LOKI-1 — Install Loki for centralized logs (Medium)
Loki is absent; Falco/application logs are not aggregated. Subject to the 4 GiB cap review.

## CR-VAULT-PERSISTENCE — Vault storage is `emptyDir` (Critical for the secrets story)
The pre-existing Vault release stores data on an **emptyDir**, so **every Vault restart wipes** the
`boutique/` mount, the `kubernetes` auth method, the policy and the secrets. ExternalSecret then fails
with `could not get secret data from provider` until Vault is re-seeded.
- **Evidence:** `kubectl -n vault get sts vault -o jsonpath='{...volumes...}'` → `home -> {}` (emptyDir);
  `vault secrets list | grep boutique` empty after a restart; ESO SecretStore `unable to create client`.
- **Impact:** project secrets (and the operator's other projects) become unavailable after each Vault
  restart; no rotation is durable.
- **Stopgap:** `security/vault-bootstrap.sh` re-seeds from the live Kubernetes Secrets (idempotent).
- **Fix (operator, shared component):** give Vault persistent storage (PVC) — e.g. change the Vault Helm
  release to use `dataStorage` (PVC) with the cluster's `local-path` StorageClass, then re-init/unseal.
  This is a change to an existing component and needs the operator's approval + a backup first.

## CR-003 — Runtime security / scanning — PARTIALLY RESOLVED
- **Trivy Operator INSTALLED** (`trivy-system`); ConfigAuditReports + ExposedSecretReports produced for
  `boutique-*`. Vulnerability scanning disabled (capacity: node CPU hit ~70%, DB init did not complete).
  Re-enable if the cluster is expanded, or run `trivy image` in CI only (already done).
- **Falco ATTEMPTED, REMOVED** — detected 12 events then crash-looped (driver parse error + container
  plugin panic) on kernel 7.0.0; legacy ebpf unsupported by the chart. Needs a different Falco
  version/driver or a runtime-security alternative. Evidence in `docs/09-runtime-security.md`.
- **Loki NOT installed** — capacity; log aggregation remains a gap.
- **kube-bench RUN** (2026-09-17): 9 PASS / 7 FAIL / 37 WARN — the 7 FAILs are kubelet file-permission checks typical of k3s; see `docs/evidence/phase9/kube-bench.txt`.

## CR-VAULT-TLS — External Secrets talks to Vault over plain HTTP (Low)
`gitops/security/eso-dev.yaml` points the SecretStore at `http://vault.vault.svc:8200` (in-cluster,
unencrypted). Traffic stays on the cluster network, but any pod that can reach the service could sniff or
meddle with the auth token exchange.
- **Fix (operator, shared component):** enable TLS on the Vault listener (cert-manager-issued cert) and
  switch the SecretStore to `https://vault.vault.svc:8200` with a `caProvider`. This changes a shared
  component and needs the operator's approval.

## CR-EMAIL-BASE — emailservice rebuilt on a newer base crash-loops in k3s (Medium)
After bumping the emailservice base to `python:3.14.7-alpine@sha256:9e9f…` (Alpine 3.24.2, to clear
fixable CVEs) the pod **crash-loops in-cluster**: the gRPC health probe never connects (exit 137 after
~30s), even though the exact image serves health `SERVING` locally. The older CI image
(`…@sha256:2a937968…`, Alpine 3.24.1) runs fine, so it is deployed again.
- **Evidence:** `kubectl -n boutique-dev describe pod -l app=emailservice` (probe failures); the image
  runs and answers `grpc.health.v1.Health/Check` locally.
- **Already tried:** IPv4-first bind (`0.0.0.0`), non-root `USER 1000`, dropping pip/ensurepip — all on
  `main`; none changed the in-cluster result.
- **Next:** compare the old/new base at the k3s runtime level (containerd image unpack / seccomp / IPv6),
  or rebuild on an intermediate base; then re-promote. Until then the PII-log redaction and the
  non-root/CVE fixes for emailservice are code-complete but **not deployed**.

## CR-UPSTREAM-REBASE — Source snapshot between upstream v0.10.6 and v0.10.7 (Low)
The `src/` tree is a snapshot of upstream `main` that already contains post-v0.10.6 commits (e.g. Go
toolchain 1.27.0 and the `checkoutservice` format-string fix), while the CI/image tags still say
`v0.10.6`. Upstream later released **v0.10.7** (2026-09-18).
- **Fix:** rebase this project's deltas (emailservice SMTP/TLS, gitops/, ci/, security/) onto upstream
  `v0.10.7` and retag. A controlled rebase, not a merge — schedule it with a full re-test.
