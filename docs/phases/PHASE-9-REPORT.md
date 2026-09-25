# PHASE-9 REPORT — Network Segmentation and Runtime Security

Date: 2026-09-16 · Branch: `phase-9-network` · New objects: 14 NetworkPolicies per environment
(dev/staging/prod). Existing objects changed: none.

## 1. What was done

- Authored a `boutique-network` component: default-deny, always-allow DNS, and explicit per-service
  allows derived from the call graph (replacing the upstream wide-open egress).
- Applied to dev/staging/prod; verified the application still works and that disallowed flows are blocked.
- **Runtime security at the time of this phase:** Falco, Trivy Operator and kube-bench were not yet
  installed (they needed an install-permission decision, CR-003, and a capacity review). **Superseded** —
  see `docs/09-runtime-security.md` and `docs/CHANGE_REQUESTS.md` (Trivy Operator installed; kube-bench
  run 2026-09-17; Falco removed after a crash-loop).

## 2. Evidence

```
boutique-dev: 14 NetworkPolicies applied; app Synced/Healthy
(1) full checkout with default-deny active: cart=302, checkout=200
(2) ALLOWED  emailservice -> mailpit:1025                connected
(3) BLOCKED  emailservice -> redis-cart:6379             ConnectionRefused
(4) BLOCKED  emailservice -> productcatalogservice:3550  ConnectionRefused
(5) BLOCKED  emailservice -> 1.1.1.1:443                 ConnectionRefused
(6) ALLOWED  emailservice -> smtp.gmail.com:587          delivered
Full transcript: docs/evidence/phase9/netpol-tests.txt
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Default-deny holds and the app still works end to end (checkout completes) | ✅ |
| Explicit egress + DNS allow; DNS footgun avoided | ✅ |
| ≥3 custom Falco rules fire with evidence | ⚠️ Falco attempted then removed (crash-loop) — CR-003 |
| Trivy Operator reports visible | ✅ installed later (`trivy-system`) — CR-003 resolved |
| kube-bench report | ✅ run later 2026-09-17 (9 PASS / 7 FAIL / 37 WARN) — CR-003 resolved |
| Test artifacts cleaned up | ✅ (tests used `exec` into an existing pod; no test objects created) |

## 4. Also fixed this phase

- Applied **CR-ARGO-1** (operator-directed, to unblock): Argo CD `repo-server` scaled to 1 replica with
  1 CPU / 1 GiB limits, ending the intermittent `DeadlineExceeded`. Reversible via
  `kubectl -n argocd rollout undo deploy/argocd-repo-server`.

## 5. Next

Phase 10 — smoke tests + DAST (ZAP) + load. Runtime-security installs remain blocked on CR-003.

---

## Addendum (runtime security executed)

- **Trivy Operator installed** (`trivy-system`): ConfigAuditReports (119) and ExposedSecretReports (1)
  are produced for `boutique-*`. Vulnerability scanning **disabled** (drove node CPU to ~70% and its DB
  init did not complete; capacity). A narrow Kyverno exclusion for `managed-by=trivy-operator` and a
  scanner egress netpol were added at the time; **both were removed in a later review fix (they were
  unnecessary — scan jobs run in `trivy-system` — and the label exclusion was a spoofable bypass).**
- **Falco installed, detected 12 real events** (`Contact K8S API Server From Container`), then entered
  `CrashLoopBackOff` on 2/3 nodes due to a driver bug (`could not parse param … openat` + a container-plugin
  panic); legacy `ebpf` is unsupported by the chart. **Falco uninstalled**, cluster verified stable.
  Custom rules authored at `security/falco/boutique-rules.yaml`.
- Full write-up: `docs/09-runtime-security.md`.

DoD update: **Trivy Operator reports visible = ✅ (config/secret)**; **≥3 Falco rules firing = ❌ blocked**
(kernel/driver), documented with evidence.

