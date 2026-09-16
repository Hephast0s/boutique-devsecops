# 00 — Threat Model (STRIDE + ranked risk register)

Method: STRIDE applied per trust boundary (see `00-architecture.md` §4), then a ranked risk register.
Every risk is application-specific and carries a file citation from Phase 0 recon. Every risk maps to a
control ID implemented in Phases 3–10. Generic filler is deliberately excluded.

Scope: the 11 deployed services + redis-cart. `shoppingassistantservice` is scanned but not deployed.
The GCP `terraform/` and kustomize GCP components are out of scope.

## Control catalogue (IDs referenced below)

| ID | Control | Phase |
|---|---|---|
| C-PSA | Pod Security Admission restricted on `boutique-*` | 3 |
| C-SECCOMP | `seccompProfile: RuntimeDefault` on all workloads | 3 |
| C-SA-TOKEN | `automountServiceAccountToken:false` + dedicated SAs | 3/8 |
| C-NET-DENY | default-deny NetworkPolicy + explicit egress + DNS allow | 9 |
| C-PIN | Pin every image by digest in GitOps overlays | 3/7 |
| C-SECRET-SCAN | gitleaks full history | 4 |
| C-SAINT | Semgrep SAST | 5 |
| C-SCA | Trivy/Grype SCA | 5 |
| C-IAC | Trivy config + Checkov + KubeLinter | 5 |
| C-DOCKERLINT | hadolint | 4 |
| C-SBOM | Syft SBOM (CycloneDX + SPDX) | 5 |
| C-SIGN | cosign sign by digest | 5 |
| C-ATTEST | cosign attest (SBOM + provenance) | 5 |
| C-VERIFY | cosign verify + verify-attestation in CI | 5 |
| C-ADMIT-SIG | Kyverno verifyImages with public key | 8 |
| C-ADMIT-PSA | Kyverno restricted policy set | 8 |
| C-ADMIT-LIMITS | Kyverno require requests/limits + probes | 8 |
| C-ADMIT-LATEST | Kyverno forbid `:latest` / require digest | 8 |
| C-ESO | Vault → External Secrets Operator | 6 |
| C-GITOPS | single GitOps controller, digest promotion | 7 |
| C-FALCO | Falco runtime rules + falcosidekick → Loki | 9 |
| C-TRIVYOP | Trivy Operator reports in `boutique-*` | 9 |
| C-KUBEBENCH | kube-bench CIS report | 9 |
| C-DAST | OWASP ZAP baseline/full on staging | 10 |
| C-SMOKE | smoke-test PostSync gate | 10 |
| C-LOAD | time-boxed load test → resource right-sizing | 10 |
| C-NEXUS | Nexus artifact proxy (supply-chain pinning) | 4 |
| C-DORA | delivery/supply-chain KPIs | 11 |

---

## Part A — STRIDE per trust boundary

### TB1 — internet/LAN → frontend
- **Spoofing:** no client authentication; anyone on the LAN reaches the app.
- **Tampering:** unvalidated input to `/product/{id}`, `/setCurrency`, `/cart` (server-rendered templates).
- **Repudiation:** no request audit trail at the edge.
- **Info disclosure:** error pages/logs may reveal internal service addresses.
- **DoS:** no rate limit; a single client can drive the full checkout fan-out.
- **EoP:** template rendering and static file serving are the only reachable surfaces.
- Controls: C-DAST, C-SMOKE, C-NET-DENY, C-GITOPS, C-FALCO.

### TB2 — frontend → internal gRPC mesh (flat network)
- **Spoofing:** any pod can call any other; no service identity, no mTLS.
- **Tampering:** a compromised service can send arbitrary RPCs to peers.
- **Repudiation:** gRPC calls are unauthenticated and unlogged centrally.
- **Info disclosure:** catalog/cart data reachable from any pod.
- **DoS:** a noisy pod can exhaust a peer; no per-service quota.
- **EoP:** lateral movement from any single compromised pod.
- Controls: C-NET-DENY (explicit allowed flows), C-FALCO, C-PSA, C-C-PIN, C-ADMIT-SIG.

### TB3 — checkoutservice → paymentservice (money path)
- **Spoofing:** any pod can invoke `Charge` directly (no caller identity).
- **Tampering:** charge amount/currency come from upstream RPC data.
- **Info disclosure:** card-like fields are processed; a real integration could log PANs.
- **DoS:** payment is in the critical checkout path; failure blocks orders.
- Controls: C-NET-DENY, C-FALCO (unexpected egress/SA-token read), C-DAST, C-LOAD.

### TB4 — any pod → redis-cart
- **Spoofing:** redis has no auth by default and uses the **default ServiceAccount**.
- **Tampering:** any pod on the network can read/write carts.
- **Info disclosure:** cart contents leak across users.
- **DoS:** cart store is shared; flush = data loss (emptyDir).
- Controls: C-NET-DENY (ingress only from cartservice), C-SA-TOKEN, C-PIN.

### TB5 — node/kubelet → container runtime (supply chain)
- **Tampering:** four distroless finals and `redis:alpine` are **unpinned/mutable**; a retagged image changes what runs.
- **Spoofing:** no signature verification today — any image runs.
- **Info disclosure:** images may carry vulnerable deps (Node 20 EOL, `rsa==4.9`).
- **EoP:** workloads without seccomp could exploit a kernel bug.
- Controls: C-PIN, C-SIGN, C-ATTEST, C-VERIFY, C-ADMIT-SIG, C-SECCOMP, C-TRIVYOP, C-KUBEBENCH, C-NEXUS.

### TB6 — CI/GitOps → cluster
- **Spoofing:** who may change running state; unsigned commits are possible today.
- **Tampering:** unprotected `main`, mutable tags, no admission gate on deploy.
- **Repudiation:** no signed history tying artifacts to builds.
- **Info disclosure:** CI logs could leak credentials if masking is wrong.
- **EoP:** over-privileged CI agents / Jenkins itself.
- Controls: C-GITOPS, C-SIGN, C-ADMIT-SIG, C-SECRET-SCAN, C-SECRET hygiene, Jenkins security review (Phase 4).

---

## Part B — Ranked risk register

Severity = Likelihood × Impact, qualitative (Critical / High / Medium / Low).
"Ref" is the file:line evidence from Phase 0.

| ID | Risk | Sev | Ref | Controls |
|---|---|---|---|---|
| R-01 | **Unpinned mutable images** — 4 distroless finals + `redis:alpine`; retag changes runtime invisibly | Critical | `src/frontend/Dockerfile:32`; `kustomize/base/cartservice.yaml:118` | C-PIN, C-SIGN, C-ADMIT-SIG |
| R-02 | **No image signature verification** — any image can be deployed | Critical | (absence of verify in all manifests) | C-SIGN, C-ATTEST, C-VERIFY, C-ADMIT-SIG |
| R-03 | **Unauthenticated plaintext internal gRPC** — any pod can call any service | High | `checkoutservice/main.go:215`; `currencyservice/server.js:190` | C-NET-DENY, C-FALCO |
| R-04 | **Flat pod network, no default-deny** — lateral movement after one compromise | High | (no NetworkPolicies applied by default) | C-NET-DENY |
| R-05 | **redis-cart on default SA + no auth + emptyDir** — cart data leak/loss | High | `kubernetes-manifests/cartservice.yaml:139-141` | C-NET-DENY, C-SA-TOKEN, C-PIN |
| R-06 | **No seccomp profile** on any workload | High | (absent in all manifests) | C-SECCOMP, C-ADMIT-PSA |
| R-07 | **SA tokens auto-mounted** on all pods (incl. redis) | High | (no `automountServiceAccountToken` anywhere) | C-SA-TOKEN, C-ADMIT-PSA |
| R-08 | **Vulnerable dependency `rsa==4.9`** in emailservice (fixed in 4.9.1) | High | `src/emailservice/requirements.txt:104` | C-SCA, C-TRIVYOP |
| R-09 | **Node 20 EOL** in currencyservice/paymentservice base images | High | `src/currencyservice/Dockerfile:18`; `src/paymentservice/Dockerfile:18` | C-SCA, C-TRIVYOP |
| R-10 | **Payment path is unauthenticated and in the critical path**; simulated charge could be replaced by a real one that logs PANs | High | `src/paymentservice/charge.js`; `checkoutservice/main.go:370` | C-NET-DENY, C-FALCO, C-DAST |
| R-11 | **`frontend-external` LoadBalancer** binds node port 80, conflicting with ingress | Medium | `kubernetes-manifests/frontend.yaml:123-136` | C-GITOPS (patch to ClusterIP), Phase 3 |
| R-12 | **No admission control** — privileged/mutable/limitless pods can be created | High | (no Kyverno/OPA present in repo) | C-ADMIT-PSA, C-ADMIT-SIG, C-ADMIT-LIMITS |
| R-13 | **No runtime detection** — malicious in-container behavior is silent | Medium | (no Falco references) | C-FALCO, C-TRIVYOP |
| R-14 | **Distroless images are undebuggable**; teams may weaken security to debug | Low | `src/frontend/Dockerfile:32` | Runbooks, ephemeral debug containers |
| R-15 | **Orphaned tests** (`checkoutservice/money`, `frontend/money`) create false confidence | Low | `src/checkoutservice/money/money_test.go` | C-SAINT/CI matrix wires `go test ./...` |
| R-16 | **No software bill of materials** — cannot answer "what is in this image" | High | (no syft/SBOM anywhere) | C-SBOM, C-ATTEST |
| R-17 | **No protected branch / signed history** upstream baseline | Medium | repo `main`, unsigned HEAD | Phase 2 protected `main` + GPG |
| R-18 | **OCI exporter major version skew** (`exporter-otlp-grpc 0.26.0` vs `sdk-node 0.221.0`) — deprecated, may silently break telemetry | Low | `src/currencyservice/package.json:18`; `src/paymentservice/package.json:17` | C-SCA |
| R-19 | **No PDBs** — a node drain can take a service to zero replicas | Medium | (no PDB objects) | C-GITOPS (staging/prod) |
| R-20 | **Exception process absent** — vulns get ignored without expiry | Medium | (no `security/exceptions.yaml`) | Phase 5 gate policy |

## Part C — Traceability matrix (risk → control → verification)

| Risk | Control(s) | Verified by (phase evidence) |
|---|---|---|
| R-01, R-02 | C-PIN, C-SIGN, C-ATTEST, C-VERIFY, C-ADMIT-SIG | cosign verify output (5); Kyverno unsigned-image rejection (8) |
| R-03, R-04 | C-NET-DENY | allowed/blocked pod transcripts (9); checkout still works (9) |
| R-05 | C-NET-DENY, C-SA-TOKEN | netpol transcript; Kyverno SA-token policy report (8/9) |
| R-06, R-07 | C-SECCOMP, C-SA-TOKEN, C-ADMIT-PSA | policy audit + enforce transcripts (8) |
| R-08, R-09, R-18 | C-SCA, C-TRIVYOP | baseline CVE table (5); Trivy Operator reports (9) |
| R-10 | C-NET-DENY, C-FALCO | Falco payment-egress rule firing (9); ZAP triage (10) |
| R-11 | Phase 3 overlay patch | `kubectl get svc` shows ClusterIP; ingress works (3) |
| R-12 | C-ADMIT-* | 4 rejection transcripts (8) |
| R-13 | C-FALCO | ≥3 custom rule alerts in Loki/Grafana (9) |
| R-14 | runbooks | runbooks index (13) |
| R-15 | CI matrix | `go test ./...` stage green incl. money tests (4) |
| R-16 | C-SBOM | non-trivial SBOM per image (5) |
| R-17 | Phase 2 | `git log --show-signature` (2) |
| R-19 | C-GITOPS | PDB objects in staging/prod (7) |
| R-20 | Phase 5 gate | expired exception fails build (5) |

## Assumptions and out of scope

- No mTLS/service mesh is introduced in this engagement (Istio manifests exist but no mesh is present);
  R-03 is mitigated at the network layer, not eliminated. Stated honestly in the ADRs.
- The payment simulation is not made PCI-compliant; the risk register records what a real integration needs.
- `shoppingassistantservice` is scanned, not deployed; its GCP attack surface is out of scope.
