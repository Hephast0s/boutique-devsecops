# PHASE-3 REPORT — Homelab-Adapted Baseline Deployment (dev)

Date: 2026-09-16 · Namespace: `boutique-dev` · Branch: `phase-3-baseline`
Existing objects changed: **none** (only new namespace + new Harbor project). Loadgenerator excluded.

## 1. What was done

- Verified Harbor access and image sources; created Harbor project `boutique`; mirrored 11 services +
  redis into Harbor; pinned every runtime image by digest.
- Built `gitops/environments/dev/` on `kustomize/base` using the `container-images-registry` and
  `without-loadgenerator` components, plus homelab hardening patches.
- Applied to `boutique-dev`; validated a full checkout transaction through the ingress.

## 2. Commands run (highlights)

```
curl -u admin:<pw> .../api/v2.0/projects ; POST /projects {"project_name":"boutique"}
docker pull|tag|push  us-central1-docker.pkg.dev/.../<svc>:v0.10.6 -> 192.168.1.8:30082/boutique/<svc>:v0.10.6
kubectl kustomize gitops/environments/dev > /tmp/opencode/dev-render.yaml
kubectl apply -f /tmp/opencode/dev-render.yaml
kubectl -n boutique-dev wait --for=condition=Available deployment --all --timeout=150s
curl http://boutique-dev.192.168.1.8.nip.io/_healthz   # 200
curl -c/-b cookie jar: GET / ; POST /cart ; POST /setCurrency ; POST /cart/checkout
kubectl -n boutique-dev logs deployment/checkoutservice
kubectl -n boutique-dev get all -o wide ; kubectl -n boutique-dev top pods
```

## 3. Evidence

- Pods: **11/11 Running** (10 services + redis) — `docs/evidence/phase3/get-all.txt`.
- Ingress: `_healthz=200`, home `200` (10 383 bytes).
- Checkout: `add_to_cart=302`, `set_currency=302`, `checkout=200`, page shows "Your order",
  order id `745b8baa-b1d0-11f1-aa25-cabd4c140715`; checkoutservice logged `[PlaceOrder] … user_currency="EUR"`
  and "order confirmation email sent".
- Usage: **34 mCPU / 216 MiB** total (`docs/evidence/phase3/top-pods.txt`) vs dev limits 2.33 CPU / 1.98 GiB.
- Rendered manifest archived: `docs/evidence/phase3/dev-render.yaml`.
- Image provenance: `docs/03-image-provenance-baseline.md` (+ raw `image-digests.txt`).

## 4. Definition of Done

| Item | Status |
|---|---|
| 11 deployments + redis Ready | ✅ |
| Frontend reachable via ingress | ✅ |
| Full checkout completes | ✅ |
| Nothing outside `boutique-dev` touched | ✅ |
| `kubectl top` recorded, within budget | ✅ |

## 5. Failures encountered (reported verbatim)

1. `redis-cart` `ImagePullBackOff` — the recorded digest was the Docker Hub source digest; Harbor's is
   `9c3ecc60…`. Fixed and re-applied; rollout succeeded. Documented in `03-baseline-deployment.md`.
2. `--dry-run=server` on the rendered bundle failed with `namespaces "boutique-dev" not found` because
   dry-run does not create the namespace. The real apply created it first and succeeded.

## 6. Deviations

- `seccompProfile`, `automountServiceAccountToken: false`, `nodeSelector=worker`, and the
  `frontend-external`→ClusterIP change are additions on top of upstream, as required by the engagement.
- Images are upstream mirrors (unsigned) at this phase; CI-built signed images replace them from Phase 5.

## 7. Next

Phase 4 (Jenkins CI). Jenkins is up; a Jenkins API token is still needed (CR-007) to create jobs/
credentials and wire the Kubernetes agents.
