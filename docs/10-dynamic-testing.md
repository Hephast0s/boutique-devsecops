# 10 — Dynamic Testing (smoke, DAST, load)

## Smoke tests

`tests/smoke/smoke.sh <base-url>` — healthz, home, product page, add-to-cart, currency switch, and a
full checkout (asserts "Your order"). Real results:

```
dev     : pass=7 fail=0
staging : pass=7 fail=0
prod    : pass=7 fail=0
```

A Kubernetes Job form of the smoke test (for use as an Argo CD PostSync hook) is provided in
`tests/smoke/smoke-job.yaml`; wiring it as a hook is pending because batch pods must satisfy the Phase-8
`boutique-require-probes` policy (they have no probes) and the Phase-9 default-deny NetworkPolicy
(needs an explicit egress allow to `frontend`). Both are documented, not silently skipped.

## DAST — OWASP ZAP baseline (staging)

`zap-baseline.py -t http://boutique-staging.192.168.1.8.nip.io` —
report at `docs/evidence/phase10/zap-baseline.{html,json}` (run 2026-09-16).

```
FAIL-NEW: 0   FAIL-INPROG: 0   WARN-NEW: 12   PASS: 55
```

> NOTE: this report predates the review-2 fixes. CSP (10038) and Missing Anti-clickjacking (10020) are
> now **fixed** by the Traefik `boutique-security-headers` middleware (`frameDeny: true` and a CSP with
> `frame-ancestors 'none'`), deployed to dev/staging/prod; session and currency cookies now set
> `HttpOnly; SameSite=Lax`. A re-run is needed for fresh evidence.

### Finding triage (all WARN, none FAIL)

| Rule | Finding | Triage |
|---|---|---|
| 10202 | Absence of Anti-CSRF Tokens (×5) | Accepted (ZAP-10202); stateless demo, no privileged transitions |
| 10020 | Missing Anti-clickjacking Header | **Fixed** — Traefik middleware `frameDeny: true` (all envs) |
| 10038 | Content Security Policy (CSP) Header Not Set | **Fixed** — Traefik middleware CSP (all envs) |
| 10112 | Session Management Response Identified (×4) | Accepted (ZAP-10112); informational |
| 90003 | Sub Resource Integrity Attribute Missing (×5) | Accepted (ZAP-90003); same-origin assets |
| 90004 | Cross-Origin-Embedder-Policy Header Missing (×2+) | Accepted (ZAP-90004); hardening backlog |

Re-run across more endpoints (home, product, cart, checkout) once ZAP is available:

```
zap-baseline.py -t http://boutique-staging.192.168.1.8.nip.io \
  -r docs/evidence/phase10/zap-baseline-$(date +%F).html \
  -J docs/evidence/phase10/zap-baseline-$(date +%F).json
```

Every finding is triaged in `security/exceptions.yaml` with an owner and expiry.

## Load / latency baseline (dev)

Locust (`loadgenerator`) could not be used as intended: its `FastHttpUser`/gevent resolver does not honour
`/etc/hosts`, so the container could not resolve the nip.io ingress host (`gaierror: Name does not
resolve`) even with `--add-host`. A real host-side measurement was taken instead (single client, dev
ingress):

```
GET /                : n=120  avg=90ms  p50=19ms  p95=138ms  max=5083ms  (one cold outlier)
GET /product/{id}    : n=60   avg=16ms  p50=13ms  p95=35ms   max=70ms
```

The application remained fully healthy (all pods 1/1) after the load.

**Limitation:** this is a single-client latency sample, not a concurrency load test. A proper in-cluster
`loadgenerator` Job (signed Harbor image + egress NetworkPolicy + probe-free batch pod handling) is the
follow-up.

## Next

Phase 11 — observability (ServiceMonitor/PodMonitor for `boutique-*`, Grafana dashboards, alerts).
Loki is absent, so log aggregation is documented as a gap.
