# STATE.md — Online Boutique DevSecOps Engagement

> Single resume file. A fresh agent reads THIS FIRST, then only the files it names.
> Last updated: end of Phase 1.

## CURRENT
- Phase: **3 — COMPLETE** (baseline deployed to `boutique-dev`). See `docs/phases/PHASE-3-REPORT.md`.
- Next: **Phase 4** (Jenkins CI) — Jenkins is up; needs an API token (CR-007) to create jobs/agents.
- Writes so far: Harbor project `boutique` (12 mirrored images), namespace `boutique-dev` (11 workloads +
  ingress). No existing object modified. Repo work is committed on `phase-*` branches, merged to `devsecops`.

## NEXT ACTION WHEN UNBLOCKED
1. Operator decision needed on `docs/CHANGE_REQUESTS.md` CR-001 (Jenkins up). Phase 2 can proceed on GitHub now.
2. Start Phase 2: GitHub repos `boutique-gitops` / `boutique-jenkins-library` (+ app repo), protect `main`,
   GPG identities, pre-commit controls.
3. Never create `boutique-*` cluster objects until stateful backups are confirmed (CR-009, rule 1.11).

## BLOCKED — on operator (details in docs/CHANGE_REQUESTS.md)
- **CR-001** Jenkins replicas=0 → blocks Phases 2 & 4.
- **CR-001 RESOLVED** — Jenkins scaled up (authorized), pod 3/3 on mina; anonymous API 403.
- **CR-002 RESOLVED** — Gitea dropped; GitHub is the source of truth (CR-010 resolved too).
- **Repo strategy (operator):** new repo `github.com/Hephast0s/boutique-devsecops` (admin → branch
  protection works). Branch per work-stream + a final integrated branch. Integration `devsecops`;
  work `phase-<n>-*`. The old fork `MinaC4/microservices-demo` is kept as remote `fork` (backup).
- **Branch protection ENABLED** on `main` + `devsecops`: PR required (1 review), linear history,
  no force-push, no deletion, **signed commits required**.
- **GPG:** CI-bot key `84DF9F67AAB13638` (ed25519, expires 2028-09-15) generated; public key at
  `security/gpg-ci-bot.pub`; git configured to sign (`commit.gpgsign=true`). Operator human key still missing.
- **Resource cap (operator):** this engagement may add at most **4 GiB RAM total**.
- **CR-003** install permissions: falco / trivy-operator / Loki (Loki absent).
- **CR-004** `may_install_local_tools` — missing syft/gitleaks/semgrep/hadolint/kustomize/dotnet/java.
- **CR-005..008** Vault token, Harbor robot creds, Jenkins API token, Gitea admin token.
- **CR-009** confirm stateful backups (Vault/Gitea/Harbor/JENKINS_HOME); Velero 1.18.1 is running.
- Section 0 still missing: install-permission flags, signing identity, `approval_phrase`/`continue_phrase`,
  `time_budget_per_phase`, `sudo_available`, `pre_engagement_backup`.

## DISCOVERED FACTS (real output)
### Cluster
- context `default` → `https://127.0.0.1:6443`, k3s `v1.36.2+k3s1`, containerd 2.3.2-k3s2.
- 3 nodes (corrected from operator's "2"): `mina` cp 8c/15.5Gi 192.168.1.8;
  `worker-1` 4c/5.85Gi 10.1.211.122; `worker-2` 3c/3.9Gi 10.1.211.202. Control-plane schedulable.
- Agent runs ON the control-plane host; kubeconfig `/home/mina/.kube/config`; auth `*.*` (cluster-admin).
- Traefik default IngressClass; hosts `*.192.168.1.8.nip.io`; **HTTP only (no cert-manager)**.
- StorageClass `local-path` (default, WaitForFirstConsumer). DNS `10.43.0.10`.
- k3s server has no `--disable-network-policy` → netpol controller embedded (empirical proof deferred Phase 9).
- Egress (host + in-cluster) verified open: docker.io/ghcr/gcr/quay reachable (401), mcr 200,
  npm/pypi/maven/go/nuget 200, Harbor 200, Vault 200.
### Platform (pre-existing — do NOT reinstall/upgrade)
- Kyverno v1.18.2, 8 ClusterPolicies **scoped to `hephastos` only**; policy-reporter; verify CRDs present.
- ESO v2.9.0 (its `SecretStore/vault` is InvalidProviderConfig — we do not repair it).
- Vault 2.0.3 (unsealed) NodePort 30086. Harbor 2.15.1 healthy (Trivy on) projects: apps/hephastos/library.
- Argo CD v3.4.5 (active GitOps: Application hephastos-dashboard) → **chosen controller**.
- Devtron 2.2.0 present (must NOT target boutique-*). Argo Rollouts present. Velero 1.18.1 present.
- Prometheus stack v0.92.1 + Grafana + Jaeger + otel-collector present. SonarQube present.
- **Jenkins 2.568.1 = DOWN (replicas 0). Gitea 1.27.0 = DOWN (replicas 0).**
- **Loki ABSENT. Nexus ABSENT. cert-manager ABSENT. Falco/Trivy Operator ABSENT.**
### Decisions (ADR-0001)
- Argo CD owns boutique-*; Harbor project `boutique`; key-based cosign (key in Vault);
  new boutique-*-scoped Kyverno policies; Nexus absent → PVC caches; Vault→ESO scoped mount `boutique/`.
- Interim remote: push to GitHub fork `MinaC4/microservices-demo` (operator-directed; Gitea down).
### Repository (Phase 0)
- 12 services / 12 Dockerfiles; cartservice context `src/cartservice/src`.
- 4 distroless finals + `redis:alpine` unpinned; `recommendationservice` does NOT tolerate catalog failure.
- Build/test matrix in `ci/services.yaml`; threat model 20 risks R-01..R-20.

## CREATED NAMES (this engagement)
- Local: `docs/**`, `ci/services.yaml`, `OPERATOR_ANSWERS.md`. Cluster: none retained
  (`boutique-preflight` created+deleted). Harbor/Gitea/Vault/Jenkins: none.

## COST / CONTEXT
- Phases 0–1 done. Reconnaissance delegated to sub-agents to conserve main context.
- Resume by reading only this file + the phase report named in CURRENT.
