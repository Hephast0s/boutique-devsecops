# 05 — Supply-Chain Security Policy

This policy is enforced by the Jenkins pipeline and, from Phase 8, by Kyverno admission. It is the single
reference for *what fails a build*.

## Gate policy

| Control | Tool | Fails on `main` | Fails on PR | Stage |
|---|---|---|---|---|
| Secrets | gitleaks | any finding | any finding | 3 |
| SAST | Semgrep (`p/default`) | ERROR severity (report-only initially) | report-only | 7 |
| SCA (source) | Trivy fs / Grype | CRITICAL, or HIGH with a fix | report-only (first week) | planned |
| Image vulns | Trivy image | CRITICAL, or HIGH **with a fix** (`--ignore-unfixed`) | same | 6 |
| Image misconfig | Trivy config / Dockle | FATAL | warn | planned |
| IaC | Trivy config / Checkov / KubeLinter | CRITICAL/HIGH | warn | planned |
| SBOM | Syft | missing/empty SBOM | missing | 5 |
| Signature | cosign verify | verification failure | n/a | 9 |
| Attestation | cosign verify-attestation (cyclonedx) | missing/invalid | n/a | 9 |

Implemented and verified in this phase: **secrets, image scan, SBOM, sign, attest, verify**.
SAST is wired (report-only). SCA/IaC/misconfig stages are defined here and land with the Phase 5/8 work.

## Vulnerability baseline (day one)

`frontend@sha256:4a46fa79…` (CI-built, Go, distroless):
`CRITICAL 0 · HIGH 0 · MEDIUM 2 · UNKNOWN 1`. Baseline recorded; a rising trend is itself a finding.

## Exception process

All accepted risks live in `security/exceptions.yaml` (single source). Tool ignores
(`.trivyignore`, Semgrep ignores, `.gitleaksignore`) are **generated from** this file, never hand-edited.

Each entry: `{id, type, identifier, justification, owner, expires}`.

Rules:
- An **expired** exception **fails the build** (the gate script checks dates).
- Every exception must name an owner and a concrete expiry date.
- Exceptions are reviewed at each release.

## Honest limitations

- The "expired exception fails the build" check and the Trivy/Semgrep ignore generation are specified
  here and implemented with the gate scripts in the follow-up to this phase; the current pipeline enforces
  the vuln/signature/SBOM gates directly.
- Full-keyless Sigstore (Fulcio/Rekor OIDC) is intentionally not used; see `05-key-management.md`.
