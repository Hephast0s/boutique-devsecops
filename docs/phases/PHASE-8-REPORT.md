# PHASE-8 REPORT — Admission Control (Kyverno)

Date: 2026-09-16 · Branch: `phase-8-*` · New objects: 8 `boutique-*` ClusterPolicies (7 Enforce, 1 Audit).

## 1. What was done

- Signed all 11 deployed images + mirrored/signed Mailpit so image controls are meaningful.
- Authored 8 new ClusterPolicies scoped to `boutique-*` by namespaceSelector; no existing policy touched.
- Rolled out in Audit, reviewed `PolicyReport`, fixed real findings, flipped 7 to **Enforce**.
- Verified rejection of non-compliant pods; confirmed the legitimate app is unaffected.

## 2. Evidence

```
PolicyReport (current Pods): restrict-registry/digest/resources/probes/labels/sa-token = 0 fail
Rejection tests (docs/evidence/phase8/rejection-tests.txt):
  foreign registry  -> denied by boutique-restrict-registry
  :latest           -> denied by boutique-require-digest (forbid-latest-tag)
  privileged        -> denied (PSA baseline + boutique-restricted)
  no limits         -> denied by boutique-require-resources
No test pod was created; the 11 workload pods remained 1/1 (Synced/Healthy).
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Policies Enforce-scoped to `boutique-*` only | ✅ (except P-1, see below) |
| Unsigned image rejected with evidence | ◑ verifyImages is **Audit** — see limitation; foreign-registry unsigned image IS rejected (P-2) |
| `:latest`, privileged, no-limits rejected | ✅ |
| Zero violations on legitimate workload | ✅ |
| No existing namespace affected | ✅ (scoped by label; hephastos policies untouched) |

## 4. Blocking limitation (diagnosed, not guessed)

Kyverno cannot verify signatures from Harbor because it is served over HTTP at a private IP:
```
invalid realm in www-authenticate: realm host "192.168.1.8" is a private or link-local address
```
`boutique-verify-images` therefore stays in **Audit**. Enforcing it now would block all legitimate pods.
Remediation options are in `docs/CHANGE_REQUESTS.md` (CR-KYVERNO-1).

## 5. Real findings fixed during rollout

1. `mutateDigest: true` is invalid with Audit → set false (true when enforce is possible).
2. `operator: NotMatches` and empty-probe patterns unsupported → rewrote as JMESPath `deny`/`image` pattern.
3. Stale ReplicaSets produced false `PolicyReport` failures → scoped the audit to current Pods.
4. Mailpit violated registry/digest/restricted → pinned to a signed Harbor digest and hardened.
5. Pods lacked `app.kubernetes.io/part-of` → added via the hardening component.

## 6. Next

Phase 9 — network segmentation (default-deny + explicit allows, incl. DNS) and runtime security
(Falco) + Trivy Operator. The Kyverno `generate default-deny` rule is added there alongside the allows.
