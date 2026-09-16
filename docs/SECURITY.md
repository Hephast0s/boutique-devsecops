# SECURITY — control catalogue (as-built)

Every control lists the threat it mitigates (threat-model IDs in `docs/00-threat-model.md`) and how it is
verified.

| Control | Mitigates | Implementation | Verified by |
|---|---|---|---|
| Secret scanning | R-17 | gitleaks in CI (full history on main) | build #5+; planted-secret scan (Phase 2) |
| SAST | R-15 | Semgrep `p/default` (report-only) | CI stage 7 |
| SCA / image scan | R-08, R-09, R-18 | Trivy image gate (CRIT/HIGH-with-fix) | blocked shippingservice (build #8) |
| SBOM | R-16 | Syft CycloneDX+SPDX per image, attached as cosign attestation | build #11 |
| Image signing | R-01, R-02 | cosign key-based, by digest | `cosign verify` (Phase 5) |
| Provenance | R-16 | cosign `slsaprovenance` (SLSA L2-equivalent, self-generated) | build #11 |
| Digest pinning | R-01 | every overlay image `@sha256:…` | `kubectl kustomize` per env |
| Admission: restricted | R-06, R-12 | Kyverno `boutique-restricted` (Enforce) | rejection tests (Phase 8) |
| Admission: registry/digest | R-01 | `boutique-restrict-registry`, `boutique-require-digest` | rejection tests (foreign image, `:latest`) |
| Admission: resources/probes/labels/SA-token | R-07, R-12 | `boutique-require-*`, `boutique-sa-token` (Enforce) | rejection tests |
| Signature admission | R-02 | `boutique-verify-images` (**Audit** — CR-KYVERNO-1) | warnings only |
| Network segmentation | R-03, R-04, R-05 | default-deny + explicit egress + DNS | allowed/blocked tests (Phase 9) |
| Secrets management | R-17, R-05 | Vault KV `boutique/` → ESO → Secret; rotation | rotation + cross-ns denial (Phase 6) |
| GitOps integrity | R-02, R-17 | one controller, digest promotion, signed commits, protected branches | branch protection API, `git log --show-signature` |
| Runtime detection | R-13 | **not installed** (Falco pending CR-003) | — |
| Cluster vuln scanning | R-08, R-13 | **not installed** (Trivy Operator pending CR-003) | — |
| Observability | R-13 (partial) | Grafana dashboard + Prometheus alerts | data present; rules loaded |

## Jenkins hardening

`docs/04-jenkins-security-review.md`: anonymous read disabled, controller runs no builds, agents use a
dedicated SA with no token automount, controller granted a namespace-scoped Role, Docker socket not used by
our pipeline. Findings JS-1/2/3 raised as change requests.

## Residual risk (stated)

- verifyImages is Audit → an unsigned image from Harbor would not be blocked by signature (but is blocked
  by registry/digest policies only if from another registry; same-registry unsigned is not yet blocked).
- No runtime detection and no continuous cluster scanning until CR-003 is approved.
- No mTLS between services; isolation is network-level only.
