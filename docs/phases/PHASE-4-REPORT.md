# PHASE-4 REPORT — Jenkins Continuous Integration

Date: 2026-09-16 · Branch: `phase-4-ci` · New cluster objects: `boutique-ci` ns, agent SA, controller Role/RoleBinding, `harbor-push` secret. Existing objects changed: **none**.

## 1. What was done

- Confirmed Jenkins is up and reachable; authenticated to its API using the existing `jenkins` secret
  (credentials not printed).
- Created the CI footprint: namespace `boutique-ci`, SA `jenkins-agent` (no token automount), a
  namespace-scoped Role + RoleBinding granting the controller SA permission to provision agent pods,
  and a Harbor push `docker-registry` secret.
- Authored `Jenkinsfile` (declarative) with **Kubernetes pod agents in `boutique-ci`**, **Kaniko**
  daemonless builds (no Docker socket), gitleaks secret scan, and `ci/services.yaml`-driven change
  detection (`ci/scripts/detect-changes.sh`).
- Created the Jenkins job `boutique-app-ci` (pipeline from SCM) via the REST API and ran it.

## 2. Commands / iterations (real)

```
gh api ... ; kubectl apply -f ci/k8s/boutique-ci.yaml
kubectl create secret docker-registry harbor-push ... | kubectl apply -f -
curl .../createItem?name=boutique-app-ci   # 200 with session cookie + CSRF crumb
curl .../job/boutique-app-ci/buildWithParameters?SERVICE=frontend
```

Build iterations (all real failures, fixed):
1. build #1 — `Invalid option type "timestamps"` (timestamper plugin absent) → removed the option.
2. build #2 — jnlp container crash-looped → corrected args to `['$(JENKINS_SECRET)','$(JENKINS_NAME)']`.
3. build #3 — `git: not found` in the tools container → `apk add git`.
4. build #4 — `fatal: detected dubious ownership in repository` → `git config --global --add safe.directory '*'`.
5. **build #5 — SUCCESS.**

## 3. Evidence (build #5)

```
result   : SUCCESS
duration : 371734 ms (~6m12s), cold
image    : 192.168.1.8:30082/boutique/frontend:v0.10.6-1139de7b-b5
digest   : sha256:6d85a5a7919a87ec195a65ea30815d9b3c421270f6c4a416d276c6f8fd38feb0
```
- Harbor confirms the artifact (`v0.10.6-1139de7b-b5`) alongside the mirrored `v0.10.6`.
- Console archived: `docs/evidence/phase4/console-build5.txt`.
- No docker socket: `grep -c docker.sock Jenkinsfile` → 0; agents are k8s pods in `boutique-ci`.

## 4. Definition of Done

| Item | Status | Note |
|---|---|---|
| Jenkins builds on Kubernetes pod agents, no host Docker socket | ✅ | frontend built by Kaniko in `boutique-ci` |
| Change detection implemented | ✅ | `detect-changes.sh`; selects all on shared-path change |
| Single-service build demonstrated | ✅ | `SERVICE=frontend` |
| Full 11-service build | ⏸ | not run (resource cap / time); path supports `FORCE_ALL=true` |
| Pure single-service change-triggered run | ⏸ | not demonstrated (param path used) |
| Unit tests (Go/.NET) wired | ⏸ | planned with Phase 5 gates |
| Artifacts/reports archived | ✅ | digest files archived by the job |
| GitOps auto-update | — | Phase 7 |

## 5. Jenkins security review

See `docs/04-jenkins-security-review.md`. Key: **JS-1** any authenticated user = admin;
**JS-2** default agent template exposes the Docker socket (pre-existing, unused by us);
**JS-3** `JENKINS_HOME` is a hostPath. All raised as change requests.

## 6. Design docs

`docs/04-ci-design.md`, `docs/04-ADR-0002-image-builder.md`, `ci/agents/pod-templates.yaml`.

## 7. Next

Phase 5 — security gates (SAST/SCA/SBOM/image scan), signing and attestation, wired into this pipeline.
Requires: cosign key generation and storage in Vault (Vault token — CR-005).
