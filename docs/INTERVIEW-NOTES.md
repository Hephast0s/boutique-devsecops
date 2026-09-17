# INTERVIEW NOTES — likely questions, grounded answers

1. **Why key-based cosign, not keyless?** Keyless needs public OIDC + external egress; a homelab has no
   identity story. Key-based is self-contained and verifiable offline. Private key lives in Vault.
2. **How do you prove prod runs what CI built?** Promotion is by **digest**; the same `@sha256:…` moves
   dev→staging→prod with no rebuild, and the digest carries a cosign signature + provenance attestation.
3. **A CVE lands in a base image at 2am — what happens?** CI image scan gates CRIT/HIGH-with-fix; a
   rebuild of the affected service is required. Continuous detection would need Trivy Operator (CR-003).
4. **Why Kyverno over OPA/Gatekeeper?** It was already present, supports `verifyImages`, and policy reports
   out of the box; no reason to duplicate a controller.
5. **How do you avoid breaking existing workloads?** Every policy is scoped by `namespaceSelector` to
   `boutique-*`; the pre-existing `hephastos` policies are untouched; rollouts start in Audit.
6. **Why no Docker socket?** It is a node-takeover path. Builds use Kaniko in a pod; the socket is not
   mounted (verified).
7. **How are secrets delivered?** Vault → ESO → Kubernetes Secret (`*-eso` convention). Rotation proven;
   cross-namespace reads denied by policy.
8. **What stops lateral movement?** default-deny NetworkPolicy + explicit per-service egress + DNS allow
   (proven: allowed/blocked transcripts).
9. **What is your biggest unsolved problem?** `verifyImages` cannot be enforced because Kyverno refuses the
   HTTP private-IP auth realm. Options in CR-KYVERNO-1. I did not disable it — it stays in Audit.
10. **What would you do with 10× the budget?** TLS/cert-manager + a real registry hostname (fixes
    verifyImages), mTLS/service mesh, Falco + Trivy Operator + Loki, multi-arch + reproducible builds,
    keyless signing with an internal OIDC, Velero-backed DR drills.
11. **How do you handle exceptions?** `security/exceptions.yaml` with owner + expiry; tool ignores are
    generated from it; expired exceptions fail the build.
12. **How is the pipeline reproducible?** `ci/services.yaml` is the single matrix source; change detection
    drives per-service builds; agents are versioned pod templates.
13. **How do you know a deploy is good?** Smoke tests (7/7) + Argo health + digest verification; DAST on
    staging with a triaged ZAP baseline.
14. **Rollback time?** A Git revert merged and applied by Argo; demonstrated.
15. **Why three environments?** To separate automated (dev/staging) from gated (prod, manual sync + PDBs).
16. **What did you scan but not deploy?** `shoppingassistantservice` (needs GCP); documented exclusion.
17. **How do you prevent mutable tags?** Overlay images are digest-pinned; Kyverno forbids `:latest` and
    requires `@sha256`.
18. **How is the Jenkins controller protected?** No anonymous read, `numExecutors: 0`, agents in a
    dedicated SA with no token automount, controller granted a namespace-scoped Role only.
19. **What is your evidence model?** Every claim maps to a command transcript/digest in `docs/evidence/`;
    `NOT EXECUTED` is used rather than inventing output.
20. **What is not done?** Runtime security, continuous scanning, Loki, 4 of 5 dashboards, Backstage
    registration, verifyImages enforcement — each with a change request or a documented blocker.
