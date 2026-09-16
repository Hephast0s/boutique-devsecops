# COMPARISON — vs. the previous MERN GitOps project

Honest comparison with the operator's earlier MERN e-commerce GitOps project.

| Dimension | Previous (MERN GitOps) | This (Online Boutique DevSecOps) |
|---|---|---|
| Services | a handful (Node/React + Mongo) | 11 polyglot services (Go/C#/Node/Python/Java) + Redis |
| CI | build + push | build + **gates** (secrets, image vulns, SAST) |
| Supply chain | images by tag | **SBOM + cosign sign + attest(SBOM, provenance) + verify**, digest-pinned |
| Admission | none | **Kyverno** (restricted/registry/digest/resources/probes/labels/SA-token Enforce) |
| Network | default | **default-deny + explicit egress + DNS** (proven) |
| Secrets | k8s secrets | **Vault + ESO**, rotation + cross-namespace denial proven |
| CD | Argo CD | Argo CD, three envs, **promotion by digest**, drift self-heal, Git rollback |
| Runtime security | none | **still none** (Falco blocked, CR-003) — same gap, now tracked |
| Observability | basic | one data-backed dashboard + alerts (not 5) |
| Evidence | screenshots | command transcripts, digests, rejection tests, policy reports |

## Where this is materially stronger

Supply-chain integrity (sign + attest + digest promotion), policy-as-code enforcement, network
segmentation, and a verifiable evidence trail.

## Where the previous project was (arguably) better

- It was a **complete working product** with a database; this is a demo app.
- It likely had **fewer moving parts**, so a lower operational burden.
- Its CI may have been faster (single language, no multi-toolchain matrix).

## Shared weakness

Neither has runtime detection or continuous cluster scanning. This project at least documents it with an
explicit change request (CR-003) rather than leaving it implicit.
