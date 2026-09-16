# DEMO — 10-minute walkthrough

A script for a live/interview demo. Every step has been executed and documented.

1. **The app (30s).** Open http://boutique-dev.192.168.1.8.nip.io/ — browse, add to cart, checkout.
   Show the confirmation page. Open http://mailpit.192.168.1.8.nip.io/ (dev) to see the captured email;
   mention real Gmail delivery via SMTP.
2. **Source & controls (1m).** GitHub `Hephast0s/boutique-devsecops`: protected `main`/`devsecops`,
   signed commits (`git log --show-signature`), `.pre-commit-config.yaml` (gitleaks, hadolint, …).
3. **CI (2m).** Jenkins job `boutique-app-ci` → show build #11 SUCCESS console: gitleaks → Syft SBOM →
   Trivy gate → Kaniko build → cosign sign/attest → verify. Point out **no docker socket**.
4. **Gate that bites (1m).** Show build #8: `GATE FAILED: shippingservice has CRITICAL/HIGH fixable
   vulns`.
5. **Registry (1m).** Harbor `boutique` project: tags + cosign signatures/attestations. `cosign verify`
   the frontend digest live.
6. **GitOps (1m).** Argo CD: three apps Synced/Healthy; prod is manual. Show a digest pin in
   `gitops/environments/prod/kustomization.yaml`.
7. **Admission (1m).** `kubectl -n boutique-dev run x --image=nginx` → **denied** (registry policy).
   `:latest` → denied. privileged → denied. Show `docs/evidence/phase8/rejection-tests.txt`.
8. **Network (30s).** `kubectl exec deploy/emailservice -- python3 -c "…redis-cart:6379…"` → blocked;
   mailpit → allowed.
9. **Secrets (30s).** `vault kv put boutique/dev/redis …` → the k8s secret updates in ~10s (ESO).
10. **Observability (30s).** Grafana `Boutique — Runtime & Health`; Prometheus rules `boutique.rules`.
11. **Honesty (30s).** State the limitations: verifyImages Audit (private-IP realm), Falco/Trivy
    Operator blocked, Loki absent, one dashboard. This is what a real engineer reports.

## Break-something demo

- Scale a dev deployment out-of-band → Argo reverts it (self-heal).
- `git revert` a digest promotion → Argo rolls back.
