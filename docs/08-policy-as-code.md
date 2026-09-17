# 08 — Policy as Code (Kyverno)

All policies are **new** (`boutique-*`) and scoped by `namespaceSelector.matchLabels:
app.kubernetes.io/part-of=online-boutique`, which is set on every `boutique-*` namespace. The existing 8
policies (scoped to `hephastos`) are untouched.

## Policy catalogue

| ID | Policy | Action | Threat (from 00-threat-model) |
|---|---|---|---|
| P-1 | `boutique-verify-images` (cosign public key, digest) | **Audit** (see limitation) | R-02 unsigned images |
| P-2 | `boutique-restrict-registry` (only Harbor `boutique`) | Enforce | R-01/R-02 supply chain |
| P-3 | `boutique-require-digest` (no `:latest`, require `@sha256`) | Enforce | R-01 mutable tags |
| P-4 | `boutique-restricted` (non-root, no priv-esc, drop ALL, RO rootfs, seccomp, no host ns/hostPath) | Enforce | R-06/R-12 |
| P-5 | `boutique-require-resources` (requests + limits) | Enforce | capacity/DoS |
| P-6 | `boutique-require-probes` (liveness + readiness) | Enforce | availability |
| P-7 | `boutique-require-labels` (`app.kubernetes.io/part-of`) | Enforce | ownership/traceability |
| P-8 | `boutique-sa-token` (`automountServiceAccountToken: false`) | Enforce | R-07 |

Rollout: Audit first, reviewed the `PolicyReport`, then flipped to Enforce (P-1 excepted).

## Verified enforcement (real)

Attempted in `boutique-dev`; all four were **rejected** and no pod was created
(`docs/evidence/phase8/rejection-tests.txt`):

| Attempt | Blocked by |
|---|---|
| image from `nginx:1.27` (foreign registry) | `boutique-restrict-registry` (+ digest/labels/probes/resources/restricted) |
| `192.168.1.8:30082/boutique/frontend:latest` | `boutique-require-digest` (forbid-latest-tag) |
| privileged pod | Pod Security Admission `baseline` + `boutique-restricted` |
| pod without resource limits | `boutique-require-resources` + PSA |

The legitimate application (11 workloads) remains `Synced/Healthy` with zero Enforce violations.

## Known limitation — why `verify-images` is Audit, not Enforce

Kyverno's cosign verifier rejects our registry's auth challenge:
```
invalid realm in www-authenticate: realm host "192.168.1.8" is a private or link-local address
```
Harbor is served over HTTP at a **private IP**, and Kyverno/go-containerregistry refuses to follow an
auth realm pointing at a private/link-local address (SSRF guard). Until this is addressed, enforcing
`verify-images` would block every legitimate pod. Kept in **Audit** with the finding recorded; see
`docs/CHANGE_REQUESTS.md` for the remediation options.

## Honest notes

- The rejection tests craft pods that also violate PSA/other rules; the combined denials are the evidence.
- The `generate default-deny NetworkPolicy` rule is intentionally **not** in this phase — it is added in
  Phase 9 together with the explicit allow policies, so the application is never left with deny-all and
  no allows.
