# 03 — Baseline Deployment (dev) — control group

Namespace `boutique-dev` running the unmodified upstream `v0.10.6` application, but **all images mirrored
into Harbor and pinned by digest**, with homelab hardening. This is the control group every later phase is
measured against.

## What was deployed

- Overlay: `gitops/environments/dev/` (built on `kustomize/base` + `container-images-registry` +
  `without-loadgenerator`).
- Rendered output (988 lines) archived at `docs/evidence/phase3/dev-render.yaml`.
- 11 Deployments (10 services + `redis-cart`), `loadgenerator` excluded by the component.
- Namespace labels: `part-of=online-boutique`, `environment=dev`,
  **PSA `enforce: baseline`**, `audit/warn: restricted`.
- Ingress `boutique-frontend` via Traefik: `http://boutique-dev.192.168.1.8.nip.io`.

## Homelab-specific changes vs upstream defaults

| Change | Why |
|---|---|
| All images remapped to `192.168.1.8:30082/boutique/<svc>@sha256:…` | no runtime dependency on Google's registry; immutable |
| `loadgenerator` removed | traffic generator must be on-demand only (capacity) |
| `seccompProfile: RuntimeDefault` added to every pod | closes threat R-06 |
| `automountServiceAccountToken: false` added to every pod | closes threat R-07 |
| `nodeSelector: node-type=worker` on every pod | keep app off the busy control-plane |
| `frontend-external` Service `LoadBalancer` → `ClusterIP` | avoid node port-80 conflict with Traefik |
| Ingress added | the only public entry point |

## Deploy commands (idempotent)

```bash
kubectl kustomize gitops/environments/dev > /tmp/dev-render.yaml
kubectl apply -f /tmp/dev-render.yaml
kubectl -n boutique-dev wait --for=condition=Available deployment --all --timeout=150s
```

## Evidence

**Pods — all `1/1 Running`** (10 services + redis) — `docs/evidence/phase3/get-all.txt`.

**Full checkout transaction (real, via ingress):**
```
healthz=200 ; home=200 (10383 bytes)
add_to_cart=302 ; set_currency=302 ; checkout=200 (page shows "Your order")
order id: 745b8baa-b1d0-11f1-aa25-cabd4c140715
checkoutservice logs:
  [PlaceOrder] user_id="75c5b2c5-..." user_currency="EUR"
  order confirmation email sent to "dev-test@example.com"
```

**Measured resource usage** (`docs/evidence/phase3/top-pods.txt`): total **34 mCPU / 216 MiB** actual,
against the budget (dev requests 1.17 CPU / 1.09 GiB; limits 2.33 CPU / 1.98 GiB). Comfortably inside.

## Deviations & notes

1. **Redis digest mismatch on first apply** — the first recorded digest was the Docker Hub source digest;
   Harbor stored `sha256:9c3ecc60…`. Corrected in the overlay and re-applied; verified by pull success.
   Root cause: `docker inspect .RepoDigests[0]` ordering for a re-tagged multi-source image.
2. `kubectl apply --dry-run=server` failed for namespaced resources on first run because the namespace did
   not exist yet (dry-run does not create it). The real apply created the namespace first and succeeded.
   Noted so the pattern is not mistaken for a real failure.
3. PSA is at `enforce: baseline` for this phase; `restricted` is enforced by Kyverno in Phase 8.

## Definition of Done

| Item | Status | Evidence |
|---|---|---|
| 11 deployments + redis Ready | ✅ | get-all.txt |
| Frontend reachable via ingress | ✅ | home=200, _healthz=200 |
| Full checkout completes | ✅ | order id + checkoutservice logs |
| Nothing outside `boutique-dev` touched | ✅ | only new namespace + Harbor project created |
| `kubectl top` recorded and within budget | ✅ | top-pods.txt (34m/216Mi) |
