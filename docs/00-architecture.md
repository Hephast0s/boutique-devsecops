# 00 — Architecture

Verified component and flow model of Online Boutique as it exists in this repository.
Everything here is derived from source and manifests during Phase 0; citations are `file:line`.

## 1. Component diagram

```
                         internet / homelab LAN
                                 │  HTTP
                                 ▼
                    ┌─────────────────────────┐
                    │        frontend         │  :8080  (distroless, Go)
                    │  only internet-facing   │
                    └───────────┬─────────────┘
        ┌───────────┬───────────┼───────────┬────────────┬─────────────┐
        ▼           ▼           ▼           ▼            ▼             ▼
   productcat    currency      cart    recommendation  shipping       ad
    :3550         :7000       :7070        :8080        :50051       :9555
   (distroless)  (node)      (.NET)      (python)     (distroless)  (java)
                                │
                                ▼
                          redis-cart :6379   (redis:alpine, emptyDir)

   frontend ──► checkoutservice :5050 (distroless, Go)
                     │  PlaceOrder fan-out
      ┌──────────────┼────────────┬───────────┬───────────┬───────────┐
      ▼              ▼            ▼           ▼           ▼           ▼
   shipping       cart         catalog     currency    payment      email
   (GetQuote,   (GetCart,     (GetProduct)(Convert)   (Charge)   (SendOrder
    ShipOrder)   EmptyCart)                                           Confirmation)
```

### Serves / calls matrix (from `protos/demo.proto` + source)

| Service | Serves | Calls |
|---|---|---|
| frontend | — (HTTP) | catalog, currency, cart, recommendation, shipping, ad, checkout |
| checkoutservice | `PlaceOrder` | shipping, cart, catalog, currency, payment, email |
| productcatalogservice | `ListProducts`, `GetProduct`, `SearchProducts` | — |
| cartservice | `AddItem`, `GetCart`, `EmptyCart` | — |
| currencyservice | `GetSupportedCurrencies`, `Convert` | — |
| shippingservice | `GetQuote`, `ShipOrder` | — |
| paymentservice | `Charge` | — |
| emailservice | `SendOrderConfirmation` | — |
| recommendationservice | `ListRecommendations` | catalog (`recommendation_server.py:73`) |
| adservice | `GetAds` | — |

## 2. Checkout transaction — end-to-end request flow

Browser flow (frontend HTTP → gRPC fan-out), traced from `src/frontend/handlers.go` and
`src/checkoutservice/main.go`:

1. User builds a cart: `POST /cart` → catalog.GetProduct (enrich) + cart.AddItem (`frontend/rpc.go:52,68`).
2. Cart view: `GET /cart` → cart.GetCart + currency.Convert per item + shipping.GetQuote
   (`frontend/rpc.go:58,81,88`).
3. `POST /cart/checkout` → frontend calls checkout.PlaceOrder (`frontend/handlers.go:354`).
4. Inside `PlaceOrder` (`checkoutservice/main.go:230`):
   a. `cart.GetCart` (`:325`)
   b. per item: `catalog.GetProduct` (`:344`) then `currency.Convert` (`:360`)
   c. `shipping.GetQuote` (`:314`) then `currency.Convert` for shipping (`:302`)
   d. **`payment.Charge`** (`:370`) — the money step (simulated)
   e. `shipping.ShipOrder` (`:387`) — failure → `codes.Unavailable` (`:260`)
   f. `cart.EmptyCart` (`:333`, error ignored `:263`)
   g. `email.SendOrderConfirmation` (`:380`, failure only warned `:273`)
5. Frontend renders confirmation with the order ID; success also emits OTel traces if enabled.

## 3. Data flow and state

| Data | Owner | Storage | Persistence |
|---|---|---|---|
| Product catalog | productcatalogservice | JSON baked into binary | immutable per image |
| Cart | cartservice | Redis (`redis-cart`) | **ephemeral** — `emptyDir`, lost on pod restart |
| Session | frontend | client cookie `shop_session-id` | client-side |
| Orders | checkoutservice | none (returns response) | not persisted |
| Ad content | adservice | in-binary | immutable |
| Currency rates | currencyservice | in-binary | immutable |

No service writes to a durable database in the default deployment. `shoppingassistantservice`
(AlloyDB/Vertex) is the only stateful-GCP component and is **not deployed**.

## 4. Trust boundaries

```
 TB1  internet/LAN ──► frontend            (untrusted → app; only public entry)
 TB2  frontend ──► internal gRPC mesh      (same trust domain; plaintext, no auth)
 TB3  checkoutservice ──► paymentservice   (money path; plaintext, no auth)
 TB4  any pod ──► redis-cart               (plaintext; no auth; default SA)
 TB5  node/kubelet ──► container runtime   (image supply chain, admission)
 TB6  CI/GitOps ──► cluster                (who may change running state)
```

Cross-boundary observations:

- **TB2/TB3 are not actually isolated today** — every service can reach every other service on the
  flat pod network, and none authenticate. NetworkPolicy (Phase 9) + mTLS (future) are the controls.
- **TB1** has no WAF/rate-limit; the ingress controller is the only edge.
- **TB5** is the focus of Phases 5/8: signing, SBOM, attestation, Kyverno admission.
- **TB6** is the focus of Phases 2/4/7: signed commits, Jenkins authority, GitOps ownership.

## 5. Where secrets live (target design)

Today: **no secrets exist** — no `valueFrom`, no Secret/ConfigMap, no credentials in the app.
Target (implemented in Phases 6):

| Secret | Consumer | Source of truth | Delivery |
|---|---|---|---|
| Harbor pull credential | all `boutique-*` pods | Vault KV `boutique/` | Vault → ESO → `imagePullSecret` |
| Redis connection string | cartservice | Vault KV `boutique/` | Vault → ESO → Secret |
| Cosign signing key + password | Jenkins | Vault KV `boutique/` | Vault → Jenkins credential |
| Cosign public key | Kyverno verify | `boutique-gitops` (public only) | Git → ConfigMap |
| Jenkins/Gitea/Harbor tokens | Jenkins jobs | Jenkins Credentials | referenced by ID only |

Hard rule: **no secret material in Git**. ESO-managed Secrets use a distinct name convention
(`*-eso`) so kustomize/Helm never co-manage them.

## 6. Deployment topology (upstream)

- 12 workloads in a single namespace, all `Deployment`/replicas=1.
- `frontend-external` = `LoadBalancer` (would be claimed by k3s ServiceLB); internal `frontend` = ClusterIP:80→8080.
- `emailservice` Service port 5000 → container 8080.
- `redis-cart` has no dedicated ServiceAccount (default SA) and no PVC.
- No NetworkPolicies applied by default; no PDBs; no HPA; no ServiceMonitor/PodMonitor.
