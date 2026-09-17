# 04 — Jenkins Security Review

Scope: the existing Jenkins instance is an **asset and part of the attack surface** (engagement rule 1.13).
This is an **assessment**; fixes to shared config require a change request (we do not modify it).

Facts gathered read-only on 2026-09-16 (Jenkins 2.568.1-jdk21, context `default`).

## Findings

| # | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| JS-1 | **High** | Authorization is `loggedInUsersCanDoAnything` — **any authenticated user has full admin** (create jobs, run scripts, add credentials). | JCasC `authorizationStrategy.loggedInUsersCanDoAnything` | Install `matrix-auth`/`role-strategy` and define a least-privilege matrix. Change request (shared config). |
| JS-2 | **Medium** | The **default agent pod template mounts the host Docker socket** (`/var/run/docker.sock`) and `/usr/bin/docker`. Any job using it can control the node's daemon (container escape / node takeover). | default `PodTemplate` volumes; verified in JCasC | Remove those volumes from the default template; use a daemonless builder. Change request. **Our pipeline does not use the default template.** |
| JS-3 | **Medium** | **`JENKINS_HOME` is a `hostPath` volume**, bound to node `mina`. Node loss or disk failure loses jobs/credentials; backups must include this path. | `sts/jenkins` volume `jenkins-home -> ['hostPath']` | Migrate to a PVC and include it in Velero backups. Change request. |
| JS-4 | Low | No `pipeline-utility-steps`, `job-dsl`, `timestamper` plugins (68 plugins total). Not a vulnerability, but limits pipeline ergonomics and observability. | plugin list | Optional installs; `timestamper` recommended. |
| JS-5 | Low | Plugin CVE posture not verifiable without the update-center diff; no automated dependency check on Jenkins plugins. | n/a | Schedule plugin updates; track advisories. |
| JS-6 | Info | **Anonymous read is disabled** (`allowAnonymousRead: false`); anonymous `/api/json` → **403**. ✔ | live probe | Keep. |
| JS-7 | Info | Controller `numExecutors: 0` — builds never run on the controller. ✔ | JCasC | Keep. |
| JS-8 | Info | Controller SA `jenkins` **cannot** list secrets cluster-wide; the `default` agent SA has only a namespace-scoped role. ✔ | `kubectl auth can-i` | Keep. |
| JS-9 | Info | Our pipeline uses a **dedicated agent SA** (`boutique-ci/jenkins-agent`) with `automountServiceAccountToken: false`, and grants the controller a **namespace-scoped Role** in `boutique-ci` only. | `ci/k8s/boutique-ci.yaml` | Keep; revisit in Phase 8/9. |

## Agent → API blast radius

- The controller SA (`jenkins/jenkins`) was granted, by this engagement, a Role in `boutique-ci` limited to
  the pod/exec/secret operations the plugin needs. It has **no** cluster-wide rights.
- Agent pods run as `jenkins-agent` with no token automount, so a compromised build container cannot use a
  service-account token to reach the API.

## Recommended change requests

1. **JS-1** — replace `loggedInUsersCanDoAnything` with matrix/role-based auth.
2. **JS-2** — remove the host Docker socket from the default agent template.
3. **JS-3** — move `JENKINS_HOME` to a PVC and back it up (ties to CR-009).

All three are recorded in `docs/CHANGE_REQUESTS.md` as JS-CRs. None block the engagement; the pipeline we
built avoids the risky default template.
