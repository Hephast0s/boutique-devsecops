# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities privately to the repository owner (`@Hephast0s`). Do not open a public
issue for a security problem. Include reproduction steps, impact, and any suggested fix.

## Scope

This repository is a homelab/portfolio implementation of the Google Online Boutique microservices demo,
hardened with an end-to-end DevSecOps pipeline. The following are in scope:

- The 11 deployed services and `redis-cart`.
- The CI pipeline (`Jenkinsfile`, `ci/`, the Jenkins shared library).
- Supply-chain controls (SBOM, cosign signing/attestation, Kyverno admission).
- Kubernetes manifests and policies under `kustomize/`, `boutique-gitops` artifacts and `security/`.

Out of scope: `terraform/` (targets Google Cloud), `.deploystack/`, `.github/workflows/` (upstream CI,
superseded by Jenkins), and `src/shoppingassistantservice` (requires Google Cloud; scanned but not deployed).

## Security controls

The full control catalogue, mapped to the threat model, is in `docs/SECURITY.md` and `docs/00-threat-model.md`.

## Secrets

No secret material is stored in this repository. Runtime secrets flow Vault → External Secrets Operator →
Kubernetes Secret; CI secrets live in Jenkins Credentials and are referenced by ID only.

## Supported versions

Only the current `main` branch and the active engagement branch are supported.
