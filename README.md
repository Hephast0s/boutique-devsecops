> **Note:** This is an independent **DevSecOps implementation** built on top of Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo). The original upstream README is preserved at [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md).

<h1 align="center">Online Boutique — End-to-End DevSecOps on k3s</h1>

<p align="center">
A production-grade <b>software supply chain</b> and <b>GitOps</b> platform around 11 polyglot microservices + Redis, running on a 3-node k3s homelab.
</p>

<p align="center">
<a href="docs/ARCHITECTURE.md">Documentation</a> ·
<a href="http://boutique-dev.192.168.1.8.nip.io/">Live demo (dev)</a> ·
<a href="docs/DEMO.md">Demo script</a> ·
<a href="docs/EVIDENCE.md">Evidence</a>
</p>

<p align="center">
<img alt="License" src="https://img.shields.io/badge/License-Apache%202.0-blue.svg">
<img alt="Kubernetes" src="https://img.shields.io/badge/Kubernetes-k3s-326ce5.svg">
<img alt="CI" src="https://img.shields.io/badge/CI-Jenkins%20%C2%B7%20Kaniko-d24939.svg">
<img alt="Supply chain" src="https://img.shields.io/badge/Supply%20chain-SBOM%20%2B%20cosign-4b5563.svg">
<img alt="GitOps" src="https://img.shields.io/badge/GitOps-Argo%20CD-ef7b4d.svg">
<img alt="Policy" src="https://img.shields.io/badge/Policy-Kyverno-326ce5.svg">
</p>

Kubernetes makes deployment easy and supply-chain security hard. This project shows the whole chain
end-to-end: a commit is built, scanned, given an SBOM, **signed by digest**, attested, and then
deployed by GitOps — with the cluster **enforcing** the rules through admission policy and network
segmentation. Every claim is backed by real evidence under [`docs/`](docs).

## What you get 🚀

- **Verifiable supply chain** — gitleaks → hadolint → unit tests → Kaniko build → Syft SBOM → Trivy
  gate → Semgrep → cosign **sign + attest + verify**, all in one Jenkins pipeline.
- **Promotion by digest** — dev → staging → prod move the *same* signed `@sha256:…`; nothing is rebuilt.
- **Enforced at the cluster** — Kyverno (`restricted`, registry, digest, resources, probes, labels,
  SA-token) and default-deny NetworkPolicy with explicit egress + DNS.
- **Secrets never in Git** — Vault → External Secrets Operator → Kubernetes Secret, with rotation.
- **Evidence-first** — threat model, ADRs, per-phase reports, runbooks and an honest limitations list.

## Architecture

```
commit ─► Jenkins (pod agents) ─► Kaniko ─► Harbor (digest, immutable, signed)
        gitleaks · hadolint · unit tests · Syft SBOM · Trivy · Semgrep · cosign
                                                     │
                                                     ▼
                              Argo CD ─► dev / staging / prod
                                         ├─ Kyverno admission
                                         ├─ NetworkPolicy (default-deny + egress + DNS)
                                         ├─ Vault + ESO secrets
                                         └─ Prometheus / Grafana
```

## Environments

| Environment | Namespace | URL | Sync |
|---|---|---|---|
| dev | `boutique-dev` | http://boutique-dev.192.168.1.8.nip.io/ | automated (prune + self-heal) |
| staging | `boutique-staging` | http://boutique-staging.192.168.1.8.nip.io/ | automated |
| prod | `boutique-prod` | http://boutique-prod.192.168.1.8.nip.io/ | **manual** + PDBs |

## Security controls 🔐

| Area | Control |
|---|---|
| Secrets | gitleaks + pre-commit + forbidden-file guard |
| SAST / SCA / IaC / License | Semgrep · Trivy (fs + image + config + license) |
| Dockerfile hygiene | hadolint |
| SBOM | Syft (CycloneDX + SPDX), attached as a cosign attestation |
| Signing & provenance | cosign (key-based, **by digest**), SLSA-style provenance |
| Admission | Kyverno `boutique-*` — 7 policies **Enforce** (verifyImages **Audit**) |
| Network | default-deny + explicit egress + DNS allow |
| Runtime secrets | Vault KV `boutique/` → ESO → Kubernetes Secret |
| Git & GitOps | protected branches, signed commits, one controller, promotion by digest |

## Getting started

```bash
# render / deploy an environment (Argo CD reconciles automatically from Git)
kubectl kustomize gitops/environments/dev | kubectl apply -f -

# run the pipeline for a service (or FORCE_ALL=true)
curl -u <user>:<token> -X POST 'http://<jenkins>/job/boutique-app-ci/buildWithParameters?SERVICE=frontend'

# smoke test
bash tests/smoke/smoke.sh http://boutique-dev.192.168.1.8.nip.io

# verify signature + SBOM
cosign verify --key security/cosign.pub --allow-insecure-registry <image>@sha256:...
```

## Core tools

| Tool | Purpose |
|---|---|
| Kubernetes (k3s) | cluster |
| Jenkins + Kaniko | CI, daemonless image builds (no Docker socket) |
| Harbor | registry (immutability, retention, robots) |
| Syft · Trivy · Semgrep · gitleaks · hadolint | SBOM + scanning + linting |
| cosign (Sigstore) | image signing & attestation |
| Vault + External Secrets | secret management |
| Argo CD | GitOps (dev/staging/prod) |
| Kyverno | admission policy as code |
| Prometheus · Grafana | metrics, alerts, dashboards |

## Documentation

| Doc | Contents |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) · [Threat model](docs/00-threat-model.md) | as-built + STRIDE/20 risks |
| [Security](docs/SECURITY.md) · [Supply chain](docs/05-supply-chain.md) | controls & verification |
| [Secrets](docs/06-secrets-management.md) · [GitOps](docs/07-gitops.md) · [Policy](docs/08-policy-as-code.md) · [Network](docs/09-network-security.md) | deep dives |
| [Evidence](docs/EVIDENCE.md) · [Metrics](docs/METRICS.md) · [Demo](docs/DEMO.md) · [Interview notes](docs/INTERVIEW-NOTES.md) | proof & walkthrough |
| [Per-phase reports](docs/phases) · [Change requests](docs/CHANGE_REQUESTS.md) | progress & open items |

## Limitations (honest)

This is a 3-node homelab, so a few controls are constrained and documented rather than faked:
`verifyImages` is **Audit** (Kyverno refuses the HTTP/private-IP registry auth realm), **Falco** is not
running (kernel 7.0.0 driver bug), **Loki** is absent, and **Trivy Operator** vulnerability scanning is
disabled for capacity. Details and remediation options are in
[docs/CHANGE_REQUESTS.md](docs/CHANGE_REQUESTS.md) and [docs/09-runtime-security.md](docs/09-runtime-security.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE). Online Boutique is a Google Cloud sample application; this
repository is an independent DevSecOps implementation built on top of it.
