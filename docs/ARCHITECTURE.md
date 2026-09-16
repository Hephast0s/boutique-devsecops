# ARCHITECTURE (as-built)

## Cluster

- k3s v1.36.2 (3 nodes: control-plane `mina` 8c/15.5Gi + `worker-1` 4c/5.85Gi + `worker-2` 3c/3.9Gi).
- Traefik ingress; hosts `*.192.168.1.8.nip.io`; HTTP only (no cert-manager).
- StorageClass `local-path`; CoreDNS at `10.43.0.10`.
- Pre-existing platform: Kyverno, ESO, Vault, Harbor, Argo CD, Devtron, Prometheus/Grafana/Jaeger,
  SonarQube, Velero, Backstage.

## Application

11 deployable services + `redis-cart` (see `docs/00-architecture.md`). `frontend` is the only
internet-facing service; `checkoutservice` is the transaction hub. All inter-service gRPC is plaintext
(no mTLS); isolation is enforced at the network layer (Phase 9).

## Environments (`boutique-*`)

| Env | Namespace | Ingress | Sync |
|---|---|---|---|
| dev | boutique-dev | boutique-dev.192.168.1.8.nip.io | Argo automated (prune+selfHeal) |
| staging | boutique-staging | boutique-staging.192.168.1.8.nip.io | Argo automated |
| prod | boutique-prod | boutique-prod.192.168.1.8.nip.io | Argo **manual** + PDBs |
| ci | boutique-ci | — | Jenkins agent pods |
| security | boutique-security | — | ESO/Vault auth, observability objects |

## Delivery pipeline

```
commit → gitleaks → Syft SBOM → Trivy image gate → Semgrep → Kaniko build → Harbor (digest) →
cosign sign + attest(SBOM, provenance) → verify → (Phase 7) digest pin in GitOps → Argo sync
```

Image identity: `192.168.1.8:30082/boutique/<svc>@sha256:...` (signed; public key `security/cosign.pub`).

## Secrets

Vault KV v2 mount `boutique/` → Kubernetes-auth role `boutique` → per-namespace `SecretStore` → ESO
`ExternalSecret` (`*-eso` convention) → Kubernetes Secret. Rotation demonstrated (~10s). Cross-namespace
reads denied.

## Policy & network

Kyverno `boutique-*` ClusterPolicies (restricted, registry, digest, resources, probes, labels, SA-token
Enforce; verifyImages Audit) + a `boutique-network` component (default-deny, DNS, per-service allows).

## Observability

Prometheus (kube-prometheus-stack) + Grafana. Dashboard `Boutique — Runtime & Health`; alerts
`boutique-alerts`. No app-level Prometheus metrics, no Loki.

See `docs/00-architecture.md`, `docs/07-gitops.md`, `docs/09-network-security.md` for detail.
