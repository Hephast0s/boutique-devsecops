# PHASE-10 REPORT — Dynamic Testing (smoke, DAST, load)

Date: 2026-09-16 · Branch: `phase-10-testing` · New objects: none retained (tests only).

## 1. What was done

- Wrote and ran a smoke test across **dev, staging and prod** — all green.
- Ran an **OWASP ZAP baseline** against staging and triaged every finding into `security/exceptions.yaml`.
- Ran a real latency baseline against dev; recorded the Locust limitation honestly.

## 2. Evidence

```
Smoke: dev=7/7, staging=7/7, prod=7/7 (tests/smoke/smoke.sh)
ZAP:   FAIL-NEW 0, WARN-NEW 12, PASS 55  (docs/evidence/phase10/zap-baseline.{html,json})
Load:  GET / — n=120 avg=90ms p50=19ms p95=138ms
       GET /product/{id} — n=60 avg=16ms p50=13ms p95=35ms
       app healthy afterwards (all pods 1/1)
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Smoke test passes against all environments | ✅ |
| Smoke test wired as an Argo sync hook and proven to block a bad deploy | ◑ manifest provided (`tests/smoke/smoke-job.yaml`); hook wiring pending batch-pod policy/netpol handling |
| ZAP report exists with every finding triaged | ✅ (ZAP-10202, ZAP-10112, ZAP-90003, ZAP-90004) |
| Load/latency numbers recorded and fed back into sizing | ✅ (single-client baseline; see limitation) |

## 4. Real limitations

1. **Locust could not run in-container** — `FastHttpUser`/gevent ignored `/etc/hosts`, so the container
   could not resolve the nip.io host (`gaierror: Name does not resolve`) even with `--add-host`. The
   in-cluster `loadgenerator` Job (with an egress NetworkPolicy and probe-free batch handling) is the
   proper follow-up.
2. The load numbers are a **single-client latency sample**, not a concurrency test.
3. The smoke hook is not yet attached to the Argo Application.

## 5. Next

Phase 11 — observability (ServiceMonitor/PodMonitor, Grafana dashboards, alerts). Loki is absent and
recorded as a gap.
