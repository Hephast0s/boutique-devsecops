# ADR-0001 — Platform Choices

Status: **Accepted** (Phase 1) · Supersedes: none · Date: 2026-09-16

## Context

Phase 1 found the cluster already hosts almost every component this engagement needs: Kyverno 1.18.2,
ESO 2.9.0, Vault 2.0.3, Harbor 2.15.1, Argo CD 3.4.5, Devtron 2.2.0, Prometheus/Grafana, Jaeger/OTel,
SonarQube, Velero, Traefik. Rule 1.12 forbids upgrading or duplicating cluster-scoped controllers.
Two components are **installed but scaled to zero** (Jenkins, Gitea), and two planned capabilities are
**absent** (Nexus, Loki). This ADR records the choices that follow.

## Decision 1 — GitOps controller: **Argo CD** (not Devtron)

- Options: (a) Argo CD, (b) Devtron, (c) both.
- Decision: **Argo CD v3.4.5** owns `boutique-*`. Devtron must not be pointed at these namespaces.
- Why: Argo CD is demonstrably in active GitOps use (`Application/hephastos-dashboard` →
  `github.com/MinaC4/Odysseus.git`, `automated{prune,selfHeal}`); it is the pattern the operator already runs.
- Consequence: **only one controller may own `boutique-*`** to avoid dual-authority drift. A second
  controller writing the same resources is explicitly out of bounds.

## Decision 2 — Registry: **Harbor** project `boutique`

- Options: (a) Harbor (present), (b) Docker Hub (rate-limited anonymous), (c) GHCR.
- Decision: new Harbor project `boutique`; push-only robot for Jenkins, pull-only robot for the cluster;
  immutable tags + retention. Existing `apps`/`hephastos`/`library` projects are untouched.
- Why: Harbor is present, healthy, and has the Trivy scanner enabled; it is the natural runtime registry.
- Consequence: Harbor serves over **HTTP** today (no cert-manager/issuer on the cluster). Pulls must use
  the HTTP registry or a trusted CA; installing a CA on the nodes would be a node-level change →
  change request if TLS is required.

## Decision 3 — Signing: **key-based cosign**, private key in Vault

- Options: (a) keyless/Fulcio, (b) key-based cosign.
- Decision: **key-based** cosign. Generate a keypair; private key + password stored in Vault under
  `boutique/`, surfaced to Jenkins as a credential; public key published in `boutique-gitops` and consumed
  by Kyverno. Sign and verify **by digest**.
- Why: keyless requires public OIDC + external egress and an identity story that does not fit a homelab;
  key-based is self-contained and verifiable offline.
- Consequence: the engagement must document key rotation/revocation; provenance is
  **SLSA Build L2-equivalent, not certified** (stated honestly, not overclaimed).

## Decision 4 — Policy engine: **Kyverno**, new `boutique-*`-scoped policies

- Options: (a) Kyverno (present), (b) OPA/Gatekeeper (absent).
- Decision: keep Kyverno; add **new** ClusterPolicies named `boutique-*` with
  `namespaceSelector` limited to `boutique-*`. Roll out `Audit` first, then `Enforce`.
- Why: present and already used (8 policies), and it supports `verifyImages`/`ImageValidatingPolicy`.
- Consequence: the existing 8 policies are scoped to `hephastos` and are **never modified**; the
  pre-existing ESO `SecretStore/vault` is **not repaired** — we add our own in `boutique-security`.

## Decision 5 — Artifact caching: **Nexus unavailable → PVC-backed caches**

- Options: (a) Nexus proxies, (b) PVC caches, (c) no cache.
- Decision: PVC-backed toolchain caches per Jenkins agent type + Harbor as registry mirror; document
  cold-vs-warm build times.
- Why: **Nexus is not installed**; egress is stable, so caching is an optimization, not a correctness need.
- Consequence: slower cold builds; the "before/after cache" metric in Phase 4 will compare warm-cache runs.

## Decision 6 — Secrets: **Vault → ESO**, scoped mount `boutique/`

- Decision: create a scoped KV v2 path `boutique/`, a Kubernetes-auth role bound to `boutique-*` SAs,
  and a `SecretStore` in a new `boutique-security` namespace. ESO-managed Secrets use a distinct
  `*-eso` name convention so kustomize/Helm never co-manage the same object (a lesson the operator hit before).
- Consequence: no long-lived static Secret is authored in Git; rotation is demonstrated in Phase 6.

## Decision 7 — Source of truth: **GitHub** (Gitea abandoned)

- Context: the engagement originally planned three Gitea repos, but Gitea is scaled to 0 and the operator
  decided (2026-09-16) that **Git work happens on GitHub**.
- Decision: `github.com/MinaC4/microservices-demo` is the app repo; new GitHub repos are created for
  `boutique-gitops` and `boutique-jenkins-library`. Gitea is dropped from the design entirely.
- Consequence: replaces the Gitea-first plan; the engagement still forbids pushing to the **Google
  upstream** repository. Git identity is `Marshal <Hephast0s@users.noreply.github.com>`.

## Open blocker (not an ADR decision)

**Jenkins and Gitea are down (replicas 0).** Phase 2 (protected repos, webhooks) and Phase 4 (CI) cannot
start until the operator scales them up — a change to existing components, so it requires operator action
or explicit approval. Recorded in `CHANGE_REQUESTS.md`.
