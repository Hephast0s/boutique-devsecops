# 04 — CI Design (Jenkins)

## Execution model

- **Agents are Kubernetes pods** in namespace `boutique-ci`, provisioned by the Jenkins Kubernetes plugin
  (v4540). The controller runs with `numExecutors: 0` (no builds on the controller).
- **No Docker socket is mounted.** The pod template is defined inline in the `Jenkinsfile`; the cloud's
  pre-existing `default` template (which *does* mount `/var/run/docker.sock`) is **not inherited** because
  the cloud's `defaultsProviderTemplate` is empty. Verified: `grep -c docker.sock Jenkinsfile` → 0.
- Images are built **daemonless with Kaniko** (see ADR-0002).
- The matrix is `ci/services.yaml` (single source of truth); change detection is
  `ci/scripts/detect-changes.sh`.

## Pod template (containers)

| Container | Image | Role | Limits |
|---|---|---|---|
| `jnlp` | `jenkins/inbound-agent:3384.v60d89463d9e0-1` | agent tunnel | 500m / 512Mi |
| `tools` | `python:3.14-alpine` | change detection, git, orchestration | 500m / 512Mi |
| `gitleaks` | `ghcr.io/gitleaks/gitleaks:v8.30.0` | secret scan | 500m / 512Mi |
| `kaniko` | `gcr.io/kaniko-project/executor:v1.23.2-debug` | daemonless image build + push | 1.5 / 2Gi |

The Harbor push credential is mounted as a `docker-registry` secret (`boutique-ci/harbor-push`) at
`/kaniko/.docker/config.json`. The agent pods run as SA `jenkins-agent` (its own SA, not `default`).

## Stages implemented (current)

| # | Stage | Tool | Blocking | Status |
|---|---|---|---|---|
| 1 | Preflight | tools (apk git, safe.directory) | yes | ✅ |
| 2 | Change Detection | `ci/scripts/detect-changes.sh` | no | ✅ |
| 3 | Secret Scan | gitleaks | yes | ✅ |
| 4 | Build & Push | Kaniko → Harbor | yes | ✅ |
| 5 | SAST (Semgrep) | — | — | Phase 5 |
| 6 | SCA (Trivy/Grype) | — | — | Phase 5 |
| 7 | SBOM (Syft) | — | — | Phase 5 |
| 8 | Image Scan (Trivy) | — | — | Phase 5 |
| 9 | IaC scan | — | — | Phase 5 |
| 10 | Sign & Attest (cosign) | — | — | Phase 5 |
| 11 | Verify / GitOps update | — | — | Phases 5/7 |

The security gates (5–11) are implemented in Phase 5 by the phase plan; this phase delivers the working
build/scan skeleton they plug into.

## Evidence — real build #5

```
outcome   : SUCCESS
duration  : 371734 ms (~6m12s), first cold build
image     : 192.168.1.8:30082/boutique/frontend:v0.10.6-1139de7b-b5
digest    : sha256:6d85a5a7919a87ec195a65ea30815d9b3c421270f6c4a416d276c6f8fd38feb0
```
Console archived at `docs/evidence/phase4/console-build5.txt`; the artifact is confirmed present in
Harbor (two artifacts: the mirrored `v0.10.6` and the CI-built tag).

## Known limitations (honest)

1. A **pure single-service change** run was not executed end-to-end; the build path was exercised via the
   `SERVICE` parameter and the change-detection script is unit-tested by inspection (branch diff correctly
   selects all services when shared paths change).
2. **Unit tests** (Go/.NET) are not yet wired into the pipeline — planned with the Phase 5 gate work.
3. The job is a plain pipeline-from-SCM, not a multibranch pipeline (webhook wiring pending).
