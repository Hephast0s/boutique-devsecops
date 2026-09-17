# CHANGE_LOG

Every object this engagement creates, with the exact create and remove command.
Cluster/remote objects are listed only from Phase 1 onward (nothing has been created remotely yet).

## Phase 0 — local repository files (no cluster writes)

All items below are new files in the working tree. They touch **nothing** outside the repository and are
not yet committed or pushed. Removal = `rm <path>` (only if abandoning the engagement).

| Created | Path | Purpose |
|---|---|---|
| 2026-09-16 | `docs/STATE.md` | session handoff / resume file |
| 2026-09-16 | `OPERATOR_ANSWERS.md` | Section 0 facts, confirmed vs missing |
| 2026-09-16 | `docs/00-application-analysis.md` | per-service analysis |
| 2026-09-16 | `docs/00-architecture.md` | component/flow/trust-boundary model |
| 2026-09-16 | `docs/00-threat-model.md` | STRIDE + 20-risk register + traceability |
| 2026-09-16 | `docs/00-build-matrix.md` | authoritative build table |
| 2026-09-16 | `ci/services.yaml` | machine-readable CI matrix (12 services) |
| 2026-09-16 | `docs/phases/PHASE-0-REPORT.md` | phase report |
| 2026-09-16 | `docs/CHANGE_LOG.md` | this file |
| 2026-09-16 | `docs/ROLLBACK.md` | teardown plan |

Read-only commands were run against the cluster (preflight only). **No Kubernetes, Gitea, Harbor, Vault,
Nexus, Jenkins or Grafana object was created, modified or deleted.** No upstream file was modified.

## Phase 1 — infrastructure discovery (read-only + one sanctioned write)

Read-only: `kubectl get/describe/top`, `helm list`, `curl` health probes. No existing object changed.

**Sanctioned temporary write (announced, logged, cleaned up):**
| Action | Exact create | Exact remove |
|---|---|---|
| egress test namespace | `kubectl create ns boutique-preflight` | `kubectl delete ns boutique-preflight` |
| egress test pod | `kubectl -n boutique-preflight run egress --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep 300` | removed with the namespace |

Cleanup proven: `kubectl get ns boutique-preflight` → `NotFound` (0 pods remaining).

Local files created: `docs/01-agent-capabilities.md`, `docs/01-infrastructure-inventory.md`,
`docs/01-capability-matrix.md`, `docs/01-capacity-budget.md`, `docs/01-ADR-0001-platform-choices.md`,
`docs/CHANGE_REQUESTS.md`, `docs/phases/PHASE-1-REPORT.md`; restore-point export under
`docs/evidence/pre-engagement/`.

**Deviation (operator-directed):** changes are committed and pushed to the GitHub fork
`origin=https://github.com/MinaC4/microservices-demo.git` because Gitea is scaled to 0. This is not the
Google upstream. See `CHANGE_REQUESTS.md` CR-010.

## Phase 2 — Git controls & platform prep (branch-based on GitHub)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| Scale Jenkins up | k8s ns `jenkins` | `kubectl -n jenkins scale statefulset jenkins --replicas=1` | `kubectl -n jenkins scale statefulset jenkins --replicas=0` |
| Create integration branch | GitHub | `git branch devsecops main && git push -u origin devsecops` | `git push origin --delete devsecops` |
| Create phase-2 work branch | GitHub | `git switch -c phase-2-git-controls devsecops` | `git push origin --delete phase-2-git-controls` |
| Create new repo | GitHub | `gh repo create Hephast0s/boutique-devsecops --public` | `gh repo delete Hephast0s/boutique-devsecops` |
| Repoint remote | local git | `git remote rename origin fork; git remote add origin https://github.com/Hephast0s/boutique-devsecops.git` | `git remote remove origin` |
| Branch protection | GitHub API | `gh api -X PUT repos/Hephast0s/boutique-devsecops/branches/{main,devsecops}/protection --input protection.json` + `.../required_signatures` | `gh api -X DELETE repos/Hephast0s/boutique-devsecops/branches/{main,devsecops}/protection` |
| CI-bot GPG key | local gpg | `gpg --quick-generate-key "boutique-ci-bot <boutique-ci-bot@users.noreply.github.com>" ed25519 sign 2y` | `gpg --delete-secret-keys 84DF9F67AAB13638 && gpg --delete-keys 84DF9F67AAB13638` |

Jenkins came up healthy (pod `jenkins-0` 3/3 on node `mina`). This is a change to an **existing**
component and was explicitly authorized by the operator. No config was modified.

### Upstream files: minimal, additive changes (documented)
- `.github/CODEOWNERS` — **additive only**: upstream Google owner line preserved; appended `@Hephast0s`
  and engagement paths (`security/`, `ci/`, `Jenkinsfile`, `gitops/`, pre-commit/gitleaks configs).
  Rationale: the fork owner must review security-sensitive paths. No upstream content removed.
- `.github/pull_request_template.md` — **left untouched**. Our checklist lives in a new sibling file
  `.github/PULL_REQUEST_TEMPLATE/devsecops.md` (GitHub offers both).

### Pre-commit execution note (resource constraint)
`pre-commit run --all-files` provisions 7 tool environments on first run (gitleaks Go binary, Python
yamllint/hadolint/ruff, Node markdownlint, shellcheck) and gitleaks scans **full git history** — too heavy
for the operator's 4 GiB cap. The hooks are defined and will run in CI (Phase 4) and on demand; the
one-time local provisioning was intentionally not completed. No upstream file was reformatted.

## Phase 3 — Homelab-adapted baseline deployment (dev)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| Create Harbor project `boutique` | Harbor API | `curl -X POST .../projects -d '{"project_name":"boutique","metadata":{"public":"true"}}'` | `curl -X DELETE .../projects/boutique` |
| Mirror 12 images into Harbor | local docker | `docker pull <GAR> ; docker tag ; docker push 192.168.1.8:30082/boutique/<svc>:v0.10.6` | delete each Harbor repository/artifact |
| Create namespace | k8s | `kubectl apply -f gitops/environments/dev` (includes namespace.yaml) | `kubectl delete ns boutique-dev` |
| Deploy baseline | k8s | `kubectl apply -f /tmp/opencode/dev-render.yaml` | `kubectl delete -f /tmp/opencode/dev-render.yaml` |
| Create ingress | k8s | included in overlay `ingress.yaml` | `kubectl -n boutique-dev delete ingress boutique-frontend` |

Additive only: no existing namespace/Harbor project/ingress was modified. `loadgenerator` excluded.

## Phase 4 — Jenkins CI

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| CI namespace + SA + RBAC | k8s | `kubectl apply -f ci/k8s/boutique-ci.yaml` | `kubectl delete ns boutique-ci` |
| Harbor push secret | k8s | `kubectl create secret docker-registry harbor-push -n boutique-ci ... --dry-run=client -o yaml \| kubectl apply -f -` | `kubectl -n boutique-ci delete secret harbor-push` |
| Jenkins job | Jenkins | `curl .../createItem?name=boutique-app-ci` | `curl .../job/boutique-app-ci/doDelete` |
| Build image | Harbor | `Kaniko → 192.168.1.8:30082/boutique/frontend:v0.10.6-<sha>-b<N>` | delete artifact in Harbor |

No existing Jenkins job/credential/config was modified. Controller SA granted a namespace-scoped Role in
`boutique-ci` only.

## Phase 5 — Supply chain (gates, SBOM, signing)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| Generate cosign keypair | local | `cosign generate-key-pair --output-key-prefix security/cosign` | `rm security/cosign.{key,pub}` |
| Store cosign key for CI | k8s | `kubectl -n boutique-ci create secret generic cosign-key --from-file=cosign.key=security/cosign.key --from-literal=COSIGN_PASSWORD=...` | `kubectl -n boutique-ci delete secret cosign-key` |
| Sign + attest images | Harbor | `cosign sign/attest --key ... <img>@sha256:...` (in CI) | delete the signature/attestation artifacts in Harbor |
| Probe tolerance patch | k8s (boutique-dev overlay) | edit `gitops/environments/dev/kustomization.yaml` + `kubectl apply` | revert the file + re-apply |
| Availability fix (incident) | k8s | raised probe `timeoutSeconds:3`, `failureThreshold:6` | revert overlay |

No existing platform object modified.

## Phase 6 — Secrets (Vault + ESO)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| KV v2 mount `boutique/` | Vault | `vault secrets enable -path=boutique kv-v2` | `vault secrets disable boutique/` |
| Policy `boutique-read` | Vault | `vault policy write boutique-read -` | `vault policy delete boutique-read` |
| Secrets | Vault | `vault kv put boutique/{dev/redis,dev/app,ci/cosign,harbor/pull} ...` | `vault kv metadata delete boutique/...` |
| Kubernetes auth | Vault | `vault auth enable kubernetes` + `vault write auth/kubernetes/config ...` + `vault write auth/kubernetes/role/boutique ...` | `vault auth disable kubernetes` |
| Reviewer SA + delegator | k8s | `kubectl apply -f gitops/security/vault-auth.yaml` | `kubectl delete -f gitops/security/vault-auth.yaml` |
| SecretStore + ExternalSecret | k8s | `kubectl apply -f gitops/security/eso-dev.yaml` | `kubectl delete -f gitops/security/eso-dev.yaml` |
| `boutique-security` namespace | k8s | included in `vault-auth.yaml` | `kubectl delete ns boutique-security` |

Existing `secret/` mount and all other Vault paths untouched.

## Phase 7 — GitOps CD (dev/staging/prod) + email delivery fix

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| AppProject + Applications | k8s (argocd) | `kubectl apply -f gitops/argocd/{project,app-dev,app-staging,app-prod}.yaml` | `kubectl -n argocd delete -f gitops/argocd/` |
| staging/prod namespaces | k8s | via Argo sync of the overlays | `kubectl delete ns boutique-staging boutique-prod` |
| Mailpit (dev mail sink) | k8s | in `gitops/environments/dev/mailpit.yaml` (Argo) | remove from overlay |
| smtp-eso ExternalSecret | k8s | `kubectl apply -f gitops/security/eso-dev.yaml` | `kubectl -n boutique-dev delete externalsecret smtp-eso` |
| Gmail SMTP creds | Vault | `vault kv put boutique/dev/smtp username=... password=...` | `vault kv metadata delete boutique/dev/smtp` |
| emailservice image (SMTP) | Harbor | `docker build/push 192.168.1.8:30082/boutique/emailservice:...` | delete artifact in Harbor |

Existing objects changed: none. Gmail App Password stored only in Vault / k8s secret `smtp-eso`
(never in Git). **Rotate it after testing** (it was shared in chat).

## Phase 8 — Admission control (Kyverno)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| 8 ClusterPolicies | k8s | `kubectl apply -f gitops/policies/boutique-policies.yaml` | `kubectl delete -f gitops/policies/boutique-policies.yaml` |
| Signed all deployed images | Harbor | `cosign sign --key security/cosign.key <img>@sha256:...` | delete signature artifacts |
| Mailpit mirror+sign | Harbor | `docker push 192.168.1.8:30082/boutique/mailpit@...; cosign sign ...` | delete artifact |

Existing Kyverno policies (hephastos-scoped) untouched. `boutique-verify-images` kept in Audit
(CR-KYVERNO-1).

## Phase 9 — Network segmentation

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| NetworkPolicies (14/env) | k8s | via `boutique-network` component in overlays (Argo) | remove component / `kubectl -n <env> delete netpol -l app.kubernetes.io/part-of=online-boutique` |
| Argo repo-server resources (operator-directed, CR-ARGO-1) | k8s (argocd) | `kubectl -n argocd patch deploy argocd-repo-server` (1 replica, 1 CPU/1Gi) | `kubectl -n argocd rollout undo deploy/argocd-repo-server` |

Existing objects changed: Argo CD `argocd-repo-server` (approved/operator-directed, reversible). All
other objects are new.

## Phase 10 — Dynamic testing (smoke, DAST, load)

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| Smoke image mirror+sign | Harbor | `docker push 192.168.1.8:30082/boutique/smoke:8.11.1; cosign sign ...` | delete artifact |
| ZAP baseline | host docker | `docker run ... zaproxy/zaproxy zap-baseline.py -t http://boutique-staging...` | remove container/report |

No cluster objects retained. ZAP findings triaged in `security/exceptions.yaml`.

## Phase 12/13 — Portal integration & documentation

| Action | System | Exact create | Exact remove |
|---|---|---|---|
| Catalog + TechDocs files | git | `catalog-info.yaml`, `mkdocs.yml` | `rm` them |
| Documentation set | git | `README.md`, `docs/{ARCHITECTURE,SECURITY,EVIDENCE,METRICS,COMPARISON,DEMO,INTERVIEW-NOTES}.md`, `docs/runbooks/*`, `docs/adr/*` | `rm` them |

No cluster objects. Backstage registration pending CR-WEB-1.

## Phase 4/5 — CI gate completion (continuous)

| Action | System | Notes |
|---|---|---|
| Add CI gates 3b/5b/6b/6c/6d/7b | git | hadolint, Go+.NET unit tests, SCA-source, IaC, license, exception-expiry |
| Add pod containers hadolint/golang/dotnet | git | toolchain agents for the new stages |
| App fix: `src/checkoutservice/main.go:240` | git | `status.Errorf(codes.Internal, err.Error())` → `"%s", err` (non-constant format string, found by the unit-test gate) |

Build **#17 SUCCESS** with the full gate set; evidence `docs/evidence/phase4/console-build17-full-gates.txt`.

## (end)
