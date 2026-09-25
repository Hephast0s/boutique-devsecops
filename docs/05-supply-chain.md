# 05 — Supply Chain

## Flow

```
 source (Git +/- branch protection)
   │  commit SHA
   ▼
 Jenkins pipeline (pod agents, boutique-ci)
   ├─ 3. gitleaks        (fail on any secret)
   ├─ 4. Kaniko build    (no docker socket) ──► image by digest
   ├─ 5. Syft SBOM       (CycloneDX + SPDX)
   ├─ 6. Trivy image     (gate: CRITICAL / HIGH-with-fix)
   ├─ 8. cosign sign     (by digest) + attest (cyclonedx + slsaprovenance)
   └─ 9. cosign verify   (signature + attestation)
   ▼
 Harbor project `boutique`   (immutable releases + retention; robots)
   ▼
 GitOps (digest pin)  ──►  Phase 7
   ▼
 Kyverno verifyImages (public key + SBOM attestation)  ──►  Phase 8
   ▼
 Runtime (Falco, Trivy Operator)  ──►  Phase 9
```

## Verified evidence (frontend, digest `sha256:4a46fa79493346fc5760f4bb4b35e59127ac86a7c738f48b6940dda856cd2ec4`)

```
SBOM   : 1002 components (CycloneDX json + SPDX json)
Trivy  : CRITICAL 0 · HIGH 0 · MEDIUM 2 · UNKNOWN 1
sign   : cosign sign --key cosign.key --allow-insecure-registry  -> signature pushed
attest : cosign attest --type cyclonedx   -> SBOM attestation
attest : cosign attest --type slsaprovenance -> provenance attestation
verify : cosign verify --key cosign.pub  -> "signatures were verified against the specified public key"
verify : cosign verify-attestation --type cyclonedx -> validated
```

Raw artefacts: `docs/evidence/phase5/` (SBOM json, trivy json, verify transcripts).

## What makes this a supply chain, not just a build

1. The artifact is **immutable** (digest) and **signed**; verification is reproducible by anyone with the
   public key.
2. The **SBOM travels with the image** as a cosign attestation, so "what is in this image" is answerable
   at any time without rebuilding.
3. **Provenance** ties the digest to a builder id, source repo and commit SHA.
4. Phase 8 makes the chain **enforced**: the cluster refuses any image that cannot produce a valid
   signature + SBOM attestation, so the controls above stop being advisory.

## Honest limitations

- Transparency-log upload is disabled in CI (homelab cannot depend on public Rekor); signatures are
  key-based and verified only by the public key. No independent transparency proof.
- Provenance is SLSA Build **L2-equivalent**, self-generated, **not certified**.
- Multi-arch and reproducible builds are out of scope.
