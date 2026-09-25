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

`zap-baseline.py -t http://boutique-staging.192.168.1.8.nip.io` (ZAP `stable`, host network).
Latest run **2026-09-25**: `docs/evidence/phase10/zap-baseline-2026-09-25.{html,json}`
(previous: `zap-baseline.{html,json}`, 2026-09-16).

```
FAIL-NEW: 0   FAIL-INPROG: 0   WARN-NEW: 8   PASS: 59     (was WARN-NEW: 12, PASS: 55)
```

The 2026-09-25 re-run confirms the review-2 fixes: **CSP (10038)** and **Missing Anti-clickjacking
(10020)** are no longer reported (Traefik `boutique-security-headers` middleware: `frameDeny: true`, CSP
with `frame-ancestors 'none'`, deployed to dev/staging/prod), and cookies now set
`HttpOnly; SameSite=Lax`. With a CSP present, ZAP now reports CSP *substance* findings (10055) instead.

### Finding triage (all WARN, none FAIL)

| Rule | Finding | Triage |
|---|---|---|
| 10202 | Absence of Anti-CSRF Tokens (×5) | Accepted (ZAP-10202); stateless demo, no privileged transitions |
| 10055 | CSP: Failure to Define Directive with No Fallback | Accepted (ZAP-10055); `default-src 'self'` is set; `object-src`/`base-uri` hardening backlog |
| 10055 | CSP: style-src unsafe-inline | Accepted; the upstream templates use inline `style=` attributes |
| 90003 | Sub Resource Integrity Attribute Missing (×5) | Accepted (ZAP-90003); same-origin assets |
| 90004 | COEP / COOP / CORP header missing | Accepted (ZAP-90004); hardening backlog |
| 10063 | Permissions Policy Header Not Set | Accepted; hardening backlog |
| 10029/10112 | Cookie Poisoning / Session Management | Informational (cookie is set by design) |

`10038` (CSP not set) and `10020` (anti-clickjacking) are **fixed** and no longer appear.

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
