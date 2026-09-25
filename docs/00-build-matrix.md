# 00 — Build Matrix

Authoritative build table for Online Boutique, verified from source during Phase 0.
The machine-readable twin is `ci/services.yaml` (the Jenkins pipeline reads that file, not this one).
Build contexts are taken from `skaffold.yaml` (the authoritative map).

## Toolchain matrix

| Service | Language / runtime | Build context | Dockerfile | Final base image | Port | Proto | Prod image |
|---|---|---|---|---|---|---|---|
| adservice | Java, `sourceCompatibility=21`, JDK 25 | `src/adservice` | `src/adservice/Dockerfile` | `eclipse-temurin:25.0.4_7-jre-alpine` | 9555 | gRPC | `boutique/adservice` |
| cartservice | C# / .NET `net10.0` | **`src/cartservice/src`** | `src/cartservice/src/Dockerfile` | `mcr.microsoft.com/dotnet/runtime-deps:10.0.0-noble-chiseled` | 7070 | gRPC | `boutique/cartservice` |
| checkoutservice | Go 1.25.0 (toolchain 1.27.0) | `src/checkoutservice` | `src/checkoutservice/Dockerfile` | `gcr.io/distroless/static` (digest-pinned) | 5050 | gRPC | `boutique/checkoutservice` |
| currencyservice | Node 20.20.2 | `src/currencyservice` | `src/currencyservice/Dockerfile` | `alpine:3.24.1` + node | 7000 | gRPC | `boutique/currencyservice` |
| emailservice | Python 3.14.7 | `src/emailservice` | `src/emailservice/Dockerfile` | `python:3.14.7-alpine` | 8080 *(svc 5000)* | gRPC | `boutique/emailservice` |
| frontend | Go 1.25.0 (toolchain 1.27.0) | `src/frontend` | `src/frontend/Dockerfile` | `gcr.io/distroless/static` (digest-pinned) | 8080 | HTTP | `boutique/frontend` |
| loadgenerator | Python 3.14.7 + Locust | `src/loadgenerator` | `src/loadgenerator/Dockerfile` | `python:3.14.7-alpine` | — | none | `boutique/loadgenerator` |
| paymentservice | Node 20.20.2 | `src/paymentservice` | `src/paymentservice/Dockerfile` | `alpine:3.24.1` + node | 50051 | gRPC | `boutique/paymentservice` |
| productcatalogservice | Go 1.25.8 (toolchain 1.27.0) | `src/productcatalogservice` | `src/productcatalogservice/Dockerfile` | `gcr.io/distroless/static` (digest-pinned) | 3550 | gRPC | `boutique/productcatalogservice` |
| recommendationservice | Python 3.14.7 | `src/recommendationservice` | `src/recommendationservice/Dockerfile` | `python:3.14.7-alpine` | 8080 | gRPC | `boutique/recommendationservice` |
| shippingservice | Go 1.25.0 (toolchain 1.27.0) | `src/shippingservice` | `src/shippingservice/Dockerfile` | `gcr.io/distroless/static` (digest-pinned) | 50051 | gRPC | `boutique/shippingservice` |
| shoppingassistantservice | Python 3.14.7-slim | `src/shoppingassistantservice` | `src/shoppingassistantservice/Dockerfile` | `python:3.14.7-slim` | 8080 | HTTP | **not built for deploy — scan only** |
| redis-cart | Redis | external image | — | `redis:alpine` (unpinned) | 6379 | TCP | mirror → `boutique/redis-cart` |

## Build commands and tests

| Service | Build command | Test command (real) | Test reality |
|---|---|---|---|
| adservice | `./gradlew downloadRepos installDist` | — | none (no junit, no `src/test`) |
| cartservice | `dotnet publish src/cartservice.csproj -c Release` (SingleFile/Trimmed/self-contained) | `dotnet test src/cartservice/` | real — 3 xUnit `[Fact]`s |
| checkoutservice | `go build ./...` | `go test ./...` | real but orphaned upstream (money_test.go never run by CI) |
| currencyservice | `npm install --only=production` | — | `npm test` is a stub that exits 1 |
| emailservice | `pip install -r requirements.txt` | — | none |
| frontend | `go build ./...` | `go test ./...` | real (validator + money) |
| loadgenerator | `pip install -r requirements.txt` | — | none |
| paymentservice | `npm install --only=production` | — | `npm test` stub exits 1 |
| productcatalogservice | `go build ./...` | `go test ./...` | real (4 tests + TestMain) |
| recommendationservice | `pip install -r requirements.txt` | — | none |
| shippingservice | `go build ./...` | `go test ./...` | real (10 tests) |
| shoppingassistantservice | `pip install -r requirements.txt` | — | none; scan only |

## Build-order / cost notes for Jenkins

1. **cartservice context trap:** build context is `src/cartservice/src` but `dotnet test` runs from `src/cartservice/` (the test project is up one level). Wrong context is the #1 build failure.
2. **adservice is the memory peak:** Gradle + JDK 25, `downloadRepos` then `installDist`. Allocate ≥2 GiB and persist `~/.gradle`. No test task exists.
3. **Go toolchain directives:** every Go module asks for `toolchain go1.27.0`; the Docker builder is `golang:1.27.0-alpine`. CI agents must have Go 1.27 or a module-proxy/toolchain source (Nexus `proxy.golang.org` mirror if available).
4. **Distroless finals have no shell:** frontend, checkout, productcatalog, shipping — no `kubectl exec` debugging; use ephemeral debug containers.
5. **Mutable images:** the four `gcr.io/distroless/static` finals are now digest-pinned in this project's Dockerfiles (B-08); `redis:alpine` is pinned by digest in the GitOps overlays.
6. **Node 20 is EOL** (Apr 2026) while the repo is dated Sep 2026; both Node Dockerfiles pin `node:20.20.2-alpine`. Report as an SCA/lifecycle finding; do not silently change the build.
7. **Only non-root upstream image is cartservice** (`USER 1000`); the four distroless Go images use the *root* distroless tag. Container `securityContext` in the manifests still forces `runAsUser: 1000`, so runtime is non-root — but the image default is root.
