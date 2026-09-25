# 00 — Application Analysis (per service)

Source-verified inventory of the 12 services in `src/`. Citations are `file:line`.
Resource numbers are the **manifest requests/limits** (`kubernetes-manifests/*`, mirrored in `kustomize/base/*`).
Test reality is from Phase 0 recon; the Jenkins matrix lives in `ci/services.yaml`.

## Shared facts (all services)

- All inter-service traffic is **plaintext gRPC with no authentication and no TLS**
  (e.g. `src/frontend/main.go:230`, `src/checkoutservice/main.go:215`, `src/currencyservice/server.js:190`,
  `src/paymentservice/server.js:62`, `src/recommendationservice/recommendation_server.py:135,148`).
- No Dockerfile declares `HEALTHCHECK`; health is entirely kubelet-probe driven.
- Every workload is a single-replica `Deployment` in the upstream manifests.
- No env var uses `valueFrom`/Secret/ConfigMap anywhere; all values are literals in the manifests
  (`kubernetes-manifests/*`, `kustomize/base/*`).
- Pod securityContext sets `runAsNonRoot/runAsUser/runAsGroup/fsGroup: 1000`; containers set
  `allowPrivilegeEscalation:false`, `capabilities.drop:[ALL]`, `readOnlyRootFilesystem:true`,
  `privileged:false`. **Missing: `seccompProfile` and `automountServiceAccountToken:false`.**

---

## 1. frontend — `src/frontend`

- **Purpose:** the only internet-facing service; renders the shop UI and is the HTTP entry point.
- **Runtime:** Go `go 1.25.0` / `toolchain go1.27.0`; final `gcr.io/distroless/static` (digest-pinned).
- **Entrypoint:** `/src/server` (`src/frontend/Dockerfile:44`), `main.go`.
- **Port/protocol:** 8080 HTTP.
- **Serves:** no RPCs — HTTP routes `GET/HEAD /`, `/product/{id}`, `/cart`, `POST /cart`, `/cart/empty`,
  `/setCurrency`, `GET /logout`, `POST /cart/checkout`, `GET /assistant`, `POST /bot`,
  `/product-meta/{ids}`, `/ _healthz`, `/robots.txt`, `/static/` (`src/frontend/main.go:150-163`).
- **Consumes:** currency (GetSupportedCurrencies/Convert), catalog (ListProducts/GetProduct),
  cart (GetCart/AddItem/EmptyCart), shipping (GetQuote), recommendation (ListRecommendations),
  ad (GetAds), checkout (PlaceOrder) — `src/frontend/rpc.go:31-123`, `handlers.go:354`.
- **Required env (panic if missing):** `PRODUCT_CATALOG_SERVICE_ADDR`, `CURRENCY_SERVICE_ADDR`,
  `CART_SERVICE_ADDR`, `RECOMMENDATION_SERVICE_ADDR`, `CHECKOUT_SERVICE_ADDR`, `SHIPPING_SERVICE_ADDR`,
  `AD_SERVICE_ADDR`, `SHOPPING_ASSISTANT_SERVICE_ADDR` (`main.go:132-139`).
- **Optional env:** `PORT`, `LISTEN_ADDR`, `BASE_URL`, `ENABLE_TRACING`, `ENABLE_PROFILER`,
  `FRONTEND_MESSAGE`, `CYMBAL_BRANDING`, `ENABLE_ASSISTANT`, `ENV_PLATFORM`, `BANNER_COLOR`,
  `ENABLE_SINGLE_SHARED_SESSION` (`main.go:111-131`, `handlers.go:46-48`, `middleware.go:90`).
- **External deps:** none directly; depends on 7 internal services.
- **State:** stateless (cookie session `shop_session-id`, no server store).
- **Failure modes:** crashes at startup if any required addr is missing; tolerates recommendation and
  ad failures (logs, page still renders — `handlers.go:177-181,527-534`; ad RPC 100 ms timeout `rpc.go:120`).
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: HTTP `/_healthz` (with cookie header).
- **Build:** `go build ./...`; **Tests:** `go test ./...` from `src/frontend` — real
  (`money/money_test.go`, `validator/validator_test.go`), though upstream CI only ran `validator`.

## 2. productcatalogservice — `src/productcatalogservice`

- **Purpose:** serves the product catalog (read-only, in-binary JSON).
- **Runtime:** Go `go 1.25.8` / toolchain 1.27.0; final distroless static (digest-pinned).
- **Entrypoint:** `/src/server` (`Dockerfile:44`); impl `product_catalog.go`, `server.go`.
- **Port/protocol:** 3550 gRPC.
- **Serves:** `ListProducts` (`product_catalog.go:41`), `GetProduct` (`:47`), `SearchProducts` (`:60`).
- **Consumes:** none.
- **Env:** `PORT=3550`, `DISABLE_PROFILER=1` (plus optional `EXTRA_LATENCY` fault injector `server.go:88-97`).
- **External deps:** none (optional AlloyDB in GCP variants — out of scope).
- **State:** stateless; catalog reloads on SIGUSR1/2 (`server.go:100-113`).
- **Failure modes:** any failure is returned as gRPC error; it is the data dependency for frontend and recommender.
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 3550.
- **Build:** `go build ./...`; **Tests:** `go test ./...` — real (4 tests + TestMain).

## 3. shippingservice — `src/shippingservice`

- **Purpose:** shipping quotes and order shipment.
- **Runtime:** Go 1.25.0 / toolchain 1.27.0; distroless static (digest-pinned).
- **Entrypoint:** `/src/shippingservice` (`Dockerfile:44`).
- **Port/protocol:** 50051 gRPC.
- **Serves:** `GetQuote` (`main.go:119`), `ShipOrder` (`:142`).
- **Consumes:** none. **Env:** `PORT=50051`, `DISABLE_PROFILER=1`.
- **State:** stateless. **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 50051.
- **Build:** `go build ./...`; **Tests:** `go test ./...` — real (10 tests).

## 4. checkoutservice — `src/checkoutservice`

- **Purpose:** the transaction orchestrator (highest-value target).
- **Runtime:** Go 1.25.0 / toolchain 1.27.0; distroless static (digest-pinned).
- **Entrypoint:** `/src/checkoutservice` (`Dockerfile:44`), `main.go`.
- **Port/protocol:** 5050 gRPC.
- **Serves:** `PlaceOrder` (`main.go:230`). **Consumes:** shipping, cart, catalog, currency, payment, email
  (`main.go:314-387`).
- **Env (all required for function):** `PORT=5050`, `PRODUCT_CATALOG_SERVICE_ADDR`, `SHIPPING_SERVICE_ADDR`,
  `PAYMENT_SERVICE_ADDR`, `EMAIL_SERVICE_ADDR`, `CURRENCY_SERVICE_ADDR`, `CART_SERVICE_ADDR`
  (`kubernetes-manifests/checkoutservice.yaml:54-68`).
- **External deps:** none; fans out to 6 services.
- **State:** stateless. **Failure modes:** `ShipOrder` failure → `codes.Unavailable` (`main.go:260`);
  other failures → `codes.Internal`; cart-empty is ignored (`:263`); email failure only warned (`:273`).
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 5050.
- **Build:** `go build ./...`; **Tests:** `go test ./...` — `money/money_test.go` exists but was orphaned upstream.

## 5. cartservice — `src/cartservice/src`

- **Purpose:** per-user cart, backed by Redis.
- **Runtime:** C# `net10.0` (`cartservice.csproj:4`); final `runtime-deps:10.0.0-noble-chiseled`, **`USER 1000`** (`Dockerfile:43`).
- **Entrypoint:** `/app/cartservice` (`Dockerfile:44`); impl `src/services/CartService.cs`, store `RedisCartStore.cs`.
- **Port/protocol:** 7070 gRPC (`ASPNETCORE_HTTP_PORTS=7070`; `DOTNET_EnableDiagnostics=0`).
- **Serves:** `AddItem` (`CartService.cs:34`), `GetCart` (`:40`), `EmptyCart` (`:45`).
- **Consumes:** none. **External deps:** Redis via `REDIS_ADDR`; `Startup.cs:29,40` — falls back to in-memory
  if unset (`Startup.cs:53`) but manifests set `REDIS_ADDR=redis-cart:6379`.
- **State:** stateful-in-Redis (cart data); service pods stateless.
- **Failure modes:** store errors surface as gRPC `FailedPrecondition` (`RedisCartStore.cs:64,79,102`);
  missing cart returns empty (`:98`).
- **Resources:** req 200m/64Mi, lim 300m/128Mi. Probes: gRPC 7070.
- **Build:** `dotnet publish … PublishSingleFile,Trimmed,self-contained`; **Tests:** `dotnet test src/cartservice/` — real (3 xUnit facts).

## 6. currencyservice — `src/currencyservice`

- **Purpose:** currency list and conversion.
- **Runtime:** Node `node:20.20.2-alpine` (EOL); final `alpine:3.24.1` + node.
- **Entrypoint:** `node server.js` (`Dockerfile:45`). **Port/protocol:** 7000 gRPC.
- **Serves:** `GetSupportedCurrencies` (`server.js:128`), `Convert` (`:138`), health (`:174`).
- **Consumes:** none. **Env:** `PORT=7000`, `DISABLE_PROFILER=1`. **State:** stateless.
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 7000.
- **Build:** `npm install --only=production`; **Tests:** none — `npm test` is a stub that exits 1 (`package.json:7`).

## 7. paymentservice — `src/paymentservice`

- **Purpose:** simulated card charge (no real money movement).
- **Runtime:** Node `node:20.20.2-alpine` (EOL); final `alpine:3.24.1` + node.
- **Entrypoint:** `node index.js` (`Dockerfile:45`); charge logic `charge.js`.
- **Port/protocol:** 50051 gRPC. **Serves:** `Charge` (`server.js:41` registered `:88-93`). **Consumes:** none.
- **Env:** `PORT=50051`, `DISABLE_PROFILER=1`. **State:** stateless.
- **Failure modes:** validates card via `simple-card-validator`; simulated auth only.
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 50051.
- **Build:** `npm install --only=production`; **Tests:** none — `npm test` stub exits 1 (`package.json:8`).
  **Highest-value place to add real unit tests** (card validation, charge response).

## 8. emailservice — `src/emailservice`

- **Purpose:** order-confirmation email (dummy/local mode).
- **Runtime:** Python 3.14.7-alpine. **Entrypoint:** `python email_server.py` (`Dockerfile:54`).
- **Port/protocol:** container 8080 gRPC; **Service port is 5000** (`kubernetes-manifests/emailservice.yaml`).
- **Serves:** `SendOrderConfirmation` (`email_server.py:109`). **Consumes:** none. Insecure port `:131`.
- **Env:** `PORT=8080`, `DISABLE_PROFILER=1`. **State:** stateless. **External deps:** SMTP only if configured (dummy by default).
- **Resources:** req 100m/64Mi, lim 200m/128Mi. Probes: gRPC 8080.
- **Build:** `pip install -r requirements.txt`; **Tests:** none. **Dependency flag:** pins `rsa==4.9`, fixed in 4.9.1.

## 9. recommendationservice — `src/recommendationservice`

- **Purpose:** product recommendations based on the catalog.
- **Runtime:** Python 3.14.7-alpine. **Entrypoint:** `python recommendation_server.py` (`Dockerfile:55`).
- **Port/protocol:** 8080 gRPC. **Serves:** `ListRecommendations` (`recommendation_server.py:70`).
- **Consumes:** catalog `ListProducts` (`:73`, insecure channel `:135`).
- **Env:** `PORT=8080`, `PRODUCT_CATALOG_SERVICE_ADDR`, `DISABLE_PROFILER=1`.
- **State:** stateless. **Failure modes:** does **not** degrade on catalog failure — the exception propagates
  and `ListRecommendations` fails; the frontend is the tolerant side (`handlers.go:177-181`).
- **Resources:** req 100m/220Mi, lim 200m/450Mi (highest memory among Python services). Probes: gRPC 8080.
- **Build:** `pip install -r requirements.txt`; **Tests:** none.

## 10. adservice — `src/adservice`

- **Purpose:** contextual text ads.
- **Runtime:** Java, `sourceCompatibility=21`, built on JDK 25 (Gradle wrapper 8.14.5);
  final `eclipse-temurin:25.0.4_7-jre-alpine`. **Runs as root (no `USER`).**
- **Entrypoint:** `/app/build/install/hipstershop/bin/AdService` (`Dockerfile:44`).
- **Port/protocol:** 9555 gRPC. **Serves:** `GetAds` (`AdService.java:94`). **Consumes:** none.
- **Env:** `PORT=9555`. **State:** stateless. Probes: gRPC 9555.
- **Resources:** req 200m/180Mi, lim 300m/300Mi. **Build is the memory peak** (`downloadRepos`, `installDist`).
- **Tests:** none (no JUnit, no `src/test`).

## 11. loadgenerator — `src/loadgenerator`

- **Purpose:** Locust traffic generator. **Runtime:** Python 3.14.7-alpine.
- **Entrypoint:** `locust --host=… --headless -u ${USERS:-10} -r ${RATE:-1}` (`Dockerfile:52`).
- **Port/protocol:** none. **Init container** waits on frontend using `FRONTEND_ADDR=frontend:80`.
- **Env:** `FRONTEND_ADDR`, `USERS=10`, `RATE=1`. **State:** stateless. **No probes.**
- **Resources:** req 300m/256Mi, lim 500m/512Mi. **Must stay disabled by default** (run only as a timed Job).

## 12. shoppingassistantservice — `src/shoppingassistantservice` *(OUT OF SCOPE — scan only)*

- **Purpose:** LLM shopping assistant. **Runtime:** Python 3.14.7-slim.
- **Entrypoint:** `python shoppingassistantservice.py` (`Dockerfile:47`). **Port:** 8080 HTTP.
- **Why excluded:** requires GCP Vertex AI + AlloyDB + Secret Manager; no GCP credentials on this cluster.
  It is still **built and scanned** by CI (`ci/services.yaml: shoppingassistantservice.scanOnly: true`),
  never deployed.

---

## Redis — `redis-cart` (external image)

- Image `redis:alpine` (mutable tag), port 6379, TCP probes, **default ServiceAccount** (no dedicated SA),
  storage `emptyDir` (`kubernetes-manifests/cartservice.yaml:139-141`) → **cart data lost on restart**.
- Resources req 70m/200Mi, lim 125m/256Mi.

## Cross-cutting security findings carried into the threat model

1. Unauthenticated, plaintext internal gRPC (no mTLS, no service identity).
2. Four distroless finals + `redis:alpine` are **mutable / unpinned** → supply-chain drift risk.
3. `redis-cart` uses the default SA and ephemeral storage.
4. No `seccompProfile`; SA tokens auto-mounted on all pods.
5. `frontend-external` is a `LoadBalancer` (potential node port-80 conflict with ingress).
6. Node 20 EOL; `rsa==4.9` vulnerable in emailservice; OpenTelemetry exporter major skew in both Node services.
7. Payment path is simulated — no PCI scope today, but its code is the natural place for a real integration to leak PANs.
