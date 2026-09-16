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

## Phase 3+ — (empty; populated as objects are created)
