# 02 — Git Strategy

## Model (operator-directed, 2026-09-16)

Single repository (`github.com/MinaC4/microservices-demo`) with a **branch-per-work-stream** model and a
**final integrated branch** at the end. This replaces the original three-Gitea-repo design (Gitea dropped).

```
main                    protected trunk; only reviewed merges; never force-pushed
└── devsecops           long-lived integration branch; phase work merges here
    ├── phase-2-git-controls
    ├── phase-3-baseline
    ├── phase-4-ci
    ├── phase-5-supply-chain
    ├── ... (one branch per phase/item)
    └── final-...        cut at the end: the complete, integrated project
```

Rules:

- **Never commit directly to `main`.** All work lands via PR with a green pipeline.
- A branch per work-stream (per phase/feature). Keep branches short-lived.
- `devsecops` is the integration branch; the end-of-engagement "complete project" branch is cut from it.
- Rebase onto the base branch before merging (linear history; no merge commits on feature branches).
- Release tags `v*` are GPG-signed (see `02-signing-identities.md`).

## What lives where (single repo)

Even though it is one repository, the three logical layers stay separated by path:

| Layer | Paths | Written by | Purpose |
|---|---|---|---|
| Application | `src/`, `protos/`, `kustomize/base/`, `helm-chart/`, `kubernetes-manifests/` | humans | upstream app (security fixes + build enablement only) |
| CI / library | `Jenkinsfile`, `ci/`, `ci/scripts/`, `ci/agents/` | humans + CI | pipeline definition and shared steps |
| GitOps state | `gitops/` (overlays, policies, ExternalSecrets, Argo app defs) | **CI only**, signed commits | deployment state per environment |
| Governance | `docs/`, `security/`, `CODEOWNERS`, `SECURITY.md`, `CONTRIBUTING.md` | humans | engagement artefacts |

Promotion is **by digest**: CI builds and signs an image, then commits the digest pin to the GitOps layer.
Promotion dev → staging → prod copies the exact digest, never rebuilds. This is what makes "what runs in
prod" provably identical to "what passed the gates".

## Branch protection (GitHub)

Applied to `main` and `devsecops`:

- Require a pull request before merging (no direct pushes).
- Require status checks to pass (the Jenkins build once wired).
- Require linear history; dismiss stale approvals.
- Require signed commits.
- Restrict force pushes and deletions.

## The CI system never writes to the app layer

CI may push **only**: image digests into the GitOps layer, and release tags. It never rewrites application
source, so the provenance chain (source commit → artifact digest) is auditable.

## Why this is auditable

Every deployment digest in the GitOps layer traces back to a commit SHA that passed secret-scan, SAST,
SCA, SBOM, image-scan, signing and admission verification. A reviewer can answer "why is this running?"
by walking digest → attestation → source commit → pipeline run.
