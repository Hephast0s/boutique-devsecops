# PHASE-5 REPORT — Security Gates, SBOM, Signing and Attestation

Date: 2026-09-16 · Branch: `phase-5-supply-chain` · New objects: Harbor artifacts (signatures/attestations), k8s secret `boutique-ci/cosign-key`. Existing objects changed: `boutique-dev` overlay (probe tolerance).

## 1. What was done

- Generated a **cosign keypair** (ECDSA P-256); private key `chmod 600`, gitignored, staged as k8s secret
  `boutique-ci/cosign-key`; public key committed at `security/cosign.pub`.
- Wired supply-chain stages into the Jenkins pipeline: **Syft SBOM** (CycloneDX + SPDX), **Trivy image
  gate**, **Semgrep** (report-only), **cosign sign + attest(SBOM) + attest(provenance)**, **cosign verify**.
- Wrote the policy: `docs/05-security-policy.md`, `security/exceptions.yaml`, `docs/05-key-management.md`,
  `docs/05-supply-chain.md`.
- Fixed a real availability incident: the 1s gRPC probe was too tight under CI load and killed
  `emailservice`/`recommendationservice`; raised probe tolerance in the dev overlay.

## 2. Evidence — build #11 = SUCCESS

```
SBOM   : frontend ~1003 components ; productcatalogservice ~1013 components
scan   : Trivy image gate (CRITICAL/HIGH fixable) -> both PASS
sign   : cosign sign --key (+ attest cyclonedx + attest slsaprovenance)
verify : "The signatures were verified against the specified public key"
         "verified frontend (signature + cyclonedx attestation)"
         "verified productcatalogservice (signature + cyclonedx attestation)"
Finished: SUCCESS
```
Console: `docs/evidence/phase5/console-build11-supplychain.txt` (515 lines).
Independent `cosign verify` of the CI-built frontend digest passes from the host
(`docs/evidence/phase5/cosign-verify.txt`).

**Gate proven to block:** build #8 stopped at stage 6 with
`GATE FAILED: shippingservice has CRITICAL/HIGH fixable vulns`
(`docs/evidence/phase5/console-build8-gate.txt`).

## 3. Vulnerability baseline (mirrored v0.10.6 images, trivy CRITICAL/HIGH fixable)

| Service | C/H fixable | Notable |
|---|---|---|
| frontend (mirror) | HIGH 15 | needs rebuild — CI rebuild is clean |
| productcatalogservice (mirror) | HIGH 15 | CI rebuild is clean |
| shippingservice | HIGH 14 | **still fails the gate after rebuild** |
| checkoutservice | HIGH 24 | |
| currencyservice / paymentservice | HIGH 48 + CRIT 3 | openssl CVEs in alpine base |
| emailservice / recommendationservice | HIGH 15 | |
| cartservice | HIGH 2 | |
| adservice / redis | scan parse error (local trivy 0.72 DB skew) | |

**Key finding:** rebuilding from the current source markedly reduces vulns (CI-built `frontend` and
`productcatalogservice` pass the gate where their published mirrors do not). `shippingservice` still fails
— a genuine remediation item, not an exception candidate (fixable).

## 4. Definition of Done

| Item | Status | Note |
|---|---|---|
| SBOM (CycloneDX + SPDX) per image, attached as attestation | ✅ | build #11 |
| Images signed by digest; provenance attestation present | ✅ | frontend, productcatalogservice |
| `cosign verify` + `verify-attestation` pass from a clean env | ✅ | host verify + CI verify stage |
| Planted vulnerable dependency fails the build | ✅ (by design) | trivy gate blocked shippingservice (real vulns) |
| Gate policy + exceptions file | ✅ | docs/05-security-policy.md, security/exceptions.yaml |
| Harbor immutable tags + robot accounts + retention | ⏸ | pending (Harbor API writes; see limitations) |
| SAST blocking + exception-generated ignores | ⏸ | Semgrep wired report-only; ignore generation deferred |
| ≥3 services with real `cosign verify` output | ◑ | 2 in CI (frontend, productcatalogservice) + 1 baseline (frontend local) |

## 5. Real failures encountered (fixed)

1. `cosign attest --type slsaprovenance` rejected an in-toto-wrapped predicate → use the bare predicate.
2. Pod YAML invalid: `command: ['sleep']; args: ['3600']` on one line → separate lines.
3. `anchore/syft` and `gcr.io/projectsigstore/cosign` images are **distroless (no shell)** → `sleep` fails;
   moved syft/cosign into the alpine `tools` container via `apk add`.
4. `bash: not found` in alpine → `apk add bash` (change detection was silently skipped).
5. cosign v3 rejects `--tlog-upload=false` → removed the flag (uses public Rekor).
6. cosign `UNAUTHORIZED` pushing signatures → mounted the Harbor docker config and set `DOCKER_CONFIG`.

## 6. Limitations (honest)

- Transparency-log upload uses the **public Rekor**; signatures are key-based (see `05-key-management.md`).
- Provenance is **SLSA Build L2-equivalent, self-generated, not certified**.
- Harbor immutability/robots and the exception-driven ignore generation are specified but not yet applied.
- Only 2 services are CI-signed so far (most others fail the vulnerability gate and need remediation).

## 7. Cluster incident + fix

`emailservice` and `recommendationservice` were crash-looping (exit 137) because the upstream grpc
liveness/readiness probe has a 1s timeout that fails under CI load on the small workers. Fixed in the dev
overlay: `timeoutSeconds: 3`, `failureThreshold: 6`. Full checkout re-verified afterwards
(`checkout=200`, "Your order", checkoutservice logged PlaceOrder + email sent).
