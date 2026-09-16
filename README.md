# Online Boutique — End-to-End DevSecOps on a k3s Homelab

Google's **Online Boutique** (11 microservices + Redis) turned into a production-grade DevSecOps system on a
3-node k3s homelab: Git → Jenkins CI → security gates → SBOM + cosign signing/attestation → Harbor →
Vault/ESO secrets → Argo CD GitOps across dev/staging/prod → Kyverno admission → default-deny network →
observability.

## Architecture

```
 git (GitHub, protected + signed commits)
   │
   ▼  Jenkins (Kubernetes pod agents in boutique-ci, Kaniko — no docker socket)
   ├─ gitleaks  (secrets)             [blocking]
   ├─ Syft      (SBOM: CycloneDX+SPDX)
   ├─ Trivy     (image gate: CRIT/HIGH-with-fix)
   ├─ Semgrep   (SAST, report-only)
   ├─ Kaniko    (build → push by tag+digest)
   └─ cosign    (sign + attest SBOM + provenance, verify)
   ▼
 Harbor project `boutique`  (digest-pinned; mirrored + CI-built images)
   ▼
 Argo CD (AppProject boutique; dev/staging automated, prod manual)
   ▼  GitOps overlays (digest pins, hardening, NetworkPolicies)
 boutique-dev / boutique-staging / boutique-prod
   ├─ Kyverno (restricted, registry, digest, resources, probes, labels, sa-token)
   ├─ NetworkPolicy (default-deny + explicit egress + DNS)
   ├─ Vault → ESO → Secrets (redis, Gmail SMTP)
   └─ Grafana/Prometheus (health + resource dashboard, alerts)
```

Detailed, evidence-backed docs are in `docs/` (start with `docs/STATE.md` and `docs/ARCHITECTURE.md`).

## Live (homelab)

| Surface | URL |
|---|---|
| App — dev | http://boutique-dev.192.168.1.8.nip.io/ |
| App — staging | http://boutique-staging.192.168.1.8.nip.io/ |
| App — prod | http://boutique-prod.192.168.1.8.nip.io/ |
| Mail catcher (dev) | http://mailpit.192.168.1.8.nip.io/ |
| Jenkins | http://192.168.1.8:30081 |
| Harbor | http://harbor.192.168.1.8.nip.io/ |
| Argo CD | http://192.168.1.8:30085 |
| Grafana | http://192.168.1.8:30084 |
| Vault | http://192.168.1.8:30086 |

## How it is run

```bash
# build the dev overlay and apply (Argo CD does this automatically from git)
kubectl kustomize gitops/environments/dev | kubectl apply -f -

# run the Jenkins pipeline for one service (or FORCE_ALL)
curl -u <jenkins> -X POST 'http://192.168.1.8:30081/job/boutique-app-ci/buildWithParameters?SERVICE=frontend'

# smoke test any environment
bash tests/smoke/smoke.sh http://boutique-dev.192.168.1.8.nip.io
```

## Security controls (implemented)

Secrets scanning, image vulnerability gating, SBOM, cosign sign/attest/verify, digest pinning,
Vault+ESO secret delivery with rotation, GitOps promotion by digest, Kyverno admission (restricted,
registry, digest, resources, probes, labels, SA-token), default-deny NetworkPolicy with explicit egress
and DNS, and supply-chain observability. See `docs/SECURITY.md`.

## Intentionally out of scope

- `src/shoppingassistantservice` — requires Google Cloud (Vertex AI + AlloyDB); scanned, never deployed.
- kustomize GCP components (`alloydb`, `spanner`, `memorystore`, `google-cloud-operations`, `service-mesh-istio`).
- `terraform/` (targets GCP).

## Honest limitations

- **Sigstore verifyImages is Audit, not Enforce** — Kyverno cannot verify signatures from an HTTP registry
  on a private IP (`invalid realm ... private or link-local`). See `docs/CHANGE_REQUESTS.md` CR-KYVERNO-1.
- **Runtime security (Falco), Trivy Operator, kube-bench are not installed** — install permission pending
  (CR-003); resource cap 4 GiB.
- **Loki is absent** — no centralized logs.
- Only **one** Grafana dashboard has real data (the app exposes no Prometheus metrics; supply-chain/vuln
  dashboards need exporters or Trivy Operator).
- Some phases are partial and say so plainly in `docs/phases/PHASE-*-REPORT.md`.
