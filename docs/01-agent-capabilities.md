# 01 — Agent Capabilities, Execution Model and Egress

Read-only inventory of the machine running the commands (the k3s control-plane host `mina`).

## 1. Local toolchain (verified versions)

| Tool | Version | Notes |
|---|---|---|
| kubectl | v1.36.2+k3s1 | client matches server |
| helm | v3.14.0+g3fc9f4b | |
| git | 2.53.0 | GitHub credential helper = `gh auth git-credential` |
| gh | present | authenticated (identity resolved at commit time) |
| docker | 29.1.3 (daemon reachable) | used for ephemeral `docker run` verification only — never mounted into CI |
| trivy | 0.72.0 | |
| grype | 0.116.1 | |
| cosign | v2.6.4 | key-based signing planned (Phase 5) |
| jq | 1.8.1 | |
| yq | v4.53.3 | |
| go | 1.24.2 | NOTE: repo asks `toolchain go1.27.0`; local Go is older |
| node | v22.23.1 | |
| npm | 10.9.8 | |
| python3 | 3.14.4 | |
| openssl | 3.5.5 | |
| curl / wget | present | |

**MISSING locally:** `kustomize`, `syft`, `gitleaks`, `semgrep`, `hadolint`, `buildctl`/`buildkit`,
`nerdctl`, `java`, `mvn`, `gradle`, `dotnet`.

## 2. Execution model (decision)

`may_install_local_tools` and `may_install_buildkit_or_kaniko` are **MISSING** in Section 0, so this is
provisional and does not assume install permission:

- **Present binaries → used directly** for ad-hoc verification (kubectl, helm, trivy, grype, cosign, git...).
- **Missing tools → run ephemerally via `docker run <tool-image>`** for ad-hoc verification. This does **not**
  install anything on the host. It relies on the verified Docker daemon (29.1.3) and egress (§3).
- **CI always runs tools on Jenkins Kubernetes pod agents**, regardless of what exists locally
  (per §0.5.2) — the local model is only for verification.
- **In-cluster Jobs** are reserved for things that must run inside the cluster by nature:
  egress checks, kube-bench, ZAP, Trivy Operator.

Consequence to flag: `go` locally is 1.24.2 while the repo requests `go1.27.0`; any local Go build
would trigger a toolchain download. Preferred: build inside the pipeline's Go 1.27 agent image.

## 3. Cluster egress — tested, not assumed

The single sanctioned Phase-1 write was used: namespace `boutique-preflight` + one pod, then removed.

**Host-level (agent):**
```
registry-1.docker.io 401   ghcr.io 401   mcr.microsoft.com 200   gcr.io 401   quay.io 401
registry.npmjs.org 200     pypi.org 200  repo.maven.apache.org 200
proxy.golang.org 200       api.nuget.org/v3/index.json 200
docker.io anon token: obtained
```
**In-cluster** (pod `curlimages/curl:8.11.1`, pulled successfully from docker.io):
```
registry-1.docker.io 401   ghcr.io 401   mcr.microsoft.com 200   gcr.io 401   quay.io 401
registry.npmjs.org 200     pypi.org 200  repo.maven.apache.org 200
proxy.golang.org 200       api.nuget.org/v3/index.json 200
harbor.192.168.1.8.nip.io/api/v2.0/health 200
192.168.1.8:30086/v1/sys/health (Vault) 200
DNS: kubernetes.default.svc.cluster.local resolves via 10.43.0.10 (CoreDNS)
```
`401` is the expected unauthenticated response from registry `/v2/` endpoints — it proves reachability.
**Conclusion:** egress is stable and open enough to build all 11 images and pull all base images.
`dockerhub_credentials`: not provided → anonymous pulls are rate-limited; will be mitigated by Nexus-less
**persistent caches** and Harbor as the runtime registry.

**Cleanup proven:** `kubectl get ns boutique-preflight` → `NotFound`; zero remaining pods.

## 4. Missing capability that changes the plan

- **Nexus is absent** (no namespace, no helm release). The plan's mandatory artifact-caching tier
  (npm/maven/pypi/nuget/go proxies) is therefore **not available**. Fallback: persistent volume caches
  per toolchain + Harbor as registry mirror. This must be confirmed with the operator before Phase 4
  because it changes cold-build times materially.
