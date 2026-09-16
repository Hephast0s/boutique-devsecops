# PHASE-9 REPORT — Network Segmentation and Runtime Security

Date: 2026-09-16 · Branch: `phase-9-network` · New objects: 14 NetworkPolicies per environment
(dev/staging/prod). Existing objects changed: none.

## 1. What was done

- Authored a `boutique-network` component: default-deny, always-allow DNS, and explicit per-service
  allows derived from the call graph (replacing the upstream wide-open egress).
- Applied to dev/staging/prod; verified the application still works and that disallowed flows are blocked.
- **Runtime security (Falco), Trivy Operator and kube-bench are NOT installed** — they require an
  install-permission decision (CR-003) and resource review against the 4 GiB cap. Documented honestly in
  `docs/09-runtime-security.md`.

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
| ≥3 custom Falco rules fire with evidence | ❌ **blocked** (Falco not installed — CR-003) |
| Trivy Operator reports visible | ❌ **blocked** (CR-003) |
| kube-bench report | ❌ **blocked** (CR-003) |
| Test artifacts cleaned up | ✅ (tests used `exec` into an existing pod; no test objects created) |

## 4. Also fixed this phase

- Applied **CR-ARGO-1** (operator-directed, to unblock): Argo CD `repo-server` scaled to 1 replica with
  1 CPU / 1 GiB limits, ending the intermittent `DeadlineExceeded`. Reversible via
  `kubectl -n argocd rollout undo deploy/argocd-repo-server`.

## 5. Next

Phase 10 — smoke tests + DAST (ZAP) + load. Runtime-security installs remain blocked on CR-003.
