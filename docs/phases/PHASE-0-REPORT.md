# PHASE-0 REPORT — Deep Application Comprehension (read-only)

Date: 2026-09-16 · Cluster writes: **none** · Repo source edits: **none** (new docs only)

## 1. What was done

- Verified the operator context/cluster (read-only) and corrected the node count (3, not 2).
- Read the application via the Tier 1/2/3 strategy using **4 parallel read-only sub-agents**
  (multi-model routing, per §0.5.2) covering: Dockerfiles+skaffold, manifests, proto+entrypoints,
  dependencies+tests. Their findings were checked against a small set of first-hand commands.
- Produced the five Phase 0 deliverables plus `ci/services.yaml`.

## 2. Commands run (all read-only)

```
kubectl config current-context
kubectl version -o json | jq -r .serverVersion.gitVersion
kubectl get nodes --no-headers | wc -l
kubectl auth can-i --list
kubectl config get-contexts
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
kubectl get nodes -o wide --no-headers
kubectl get nodes -o custom-columns='NAME,ROLES,IP,KUBELET,OS' --no-headers
ls ~/.kube/ ; echo $KUBECONFIG
find src -name go.mod -o -name '*_test.go'
grep -n '"test"' src/currencyservice/package.json src/paymentservice/package.json
python3 -c "import yaml; yaml.safe_load(open('ci/services.yaml'))"    # YAML validation
wc -l docs/00-*.md docs/STATE.md ci/services.yaml
```

## 3. Real output highlights (nothing fabricated)

```
current-context = default ; server = https://127.0.0.1:6443
serverVersion   = v1.36.2+k3s1 ; containerd 2.3.2-k3s2
nodes = 3:
  mina    control-plane 192.168.1.8   Ubuntu 26.04.1
  worker-1              10.1.211.122  Ubuntu 24.04.4
  worker-2              10.1.211.202  Ubuntu 24.04.4
auth can-i --list => *.* [*]   (cluster-admin; read-only is self-imposed)
ci/services.yaml => valid yaml, services=12
  scanOnly=[shoppingassistantservice]; deploy=false=[loadgenerator, shoppingassistantservice]
```

## 4. Deliverables created (line counts vs caps)

| File | Lines | Cap | |
|---|---|---|---|
| `docs/00-application-analysis.md` | 193 | 400 | ok |
| `docs/00-architecture.md` | 123 | 400 | ok |
| `docs/00-threat-model.md` | 149 | 400 | ok |
| `docs/00-build-matrix.md` | 50 | 200 | ok |
| `ci/services.yaml` | 160 | — | valid, 12 services |
| `docs/STATE.md` | 75 | 150 | ok |
| `docs/CHANGE_LOG.md`, `docs/ROLLBACK.md` | — | — | created |

## 5. Discrepancies vs Section 2 (as required)

1. Section 2's component list **omits `container-images-tag-suffix`** (exists on disk).
2. Section 2 says "upstream image tags are pinned by digest in most Dockerfiles" — **false for the four
   distroless finals** (`gcr.io/distroless/static`, unpinned by tag and digest) and for `redis:alpine`.
3. Section 2.2 implies a dedicated ServiceAccount per service — true except **`redis-cart`, which uses the
   default SA**.
4. Section 2/implied adservice builder "alpine" — actual builder is `eclipse-temurin:…-jdk-noble`.
5. Master-prompt Phase 10 says recommendationservice "is designed to tolerate" failures — **it is the
   opposite**: recommendationservice does **not** degrade on catalog failure (`recommendation_server.py:73`);
   the *frontend* is the tolerant side. Will matter for the chaos experiment in Phase 10.
6. New findings not in Section 2: orphaned Go tests (`checkoutservice/money`, `frontend/money`);
   `rsa==4.9` in emailservice; Node 20 EOL; OTel exporter major skew; skaffold `debug` profile
   patch-index/comment mismatch.

## 6. Risks discovered (full register in `00-threat-model.md`)

20 application-specific risks (R-01…R-20), each mapped to a control. Top: unpinned mutable images
(R-01), no signature verification (R-02), flat unauthenticated gRPC (R-03/R-04), redis on default SA +
ephemeral storage (R-05).

## 7. Definition of Done

| Item | Status | Evidence |
|---|---|---|
| Every service documented with file-path citations | ✅ | `00-application-analysis.md` |
| Discrepancies vs Section 2 reported | ✅ | §5 above |
| `ci/services.yaml` valid YAML, covers all 12 | ✅ | python yaml output, services=12 |
| Threat model ≥15 app-specific risks, each mapped | ✅ | 20 risks, traceability matrix in `00-threat-model.md` |
| No Tier 3 file read in full | ✅ | agents read source/manifests only; node_modules/genproto untouched |
| Document caps respected | ✅ | §4 table |
| No cluster/remote writes | ✅ | only read verbs; `CHANGE_LOG.md` |

## 8. Cost / time

Wall-clock ≈ 25 min. Tokens: reconnaissance delegated to 4 sub-agents to keep the main-context cost low.
Cluster resources consumed: none (only API GETs).

## 9. Blocked / next

Phase 1 remains **blocked** on the unanswered Section 0 platform fields (see `OPERATOR_ANSWERS.md`).
Awaiting operator `continue` + the missing inputs before any Phase 1 discovery or write.
