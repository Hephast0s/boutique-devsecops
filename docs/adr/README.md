# ADRs

| ADR | Decision |
|---|---|
| `../01-ADR-0001-platform-choices.md` | Argo CD as GitOps controller; Harbor registry; key-based cosign; Kyverno; Nexus-absent caching; Vault+ESO; GitHub source of truth |
| `../04-ADR-0002-image-builder.md` | Kaniko (daemonless) image builds; no Docker socket |
| inline in `../05-key-management.md` | key-based signing + rotation/revocation model |
| inline in `../06-secrets-management.md` | ESO `*-eso` ownership rule; per-namespace SecretStore |
| inline in `../07-gitops.md` | one controller owns `boutique-*`; promotion by digest; prod manual |

## Decisions still open (require operator)

- **CR-KYVERNO-1** — how to let Kyverno verify signatures from the HTTP/private-IP Harbor.
- **CR-003** — install Falco / Trivy Operator / (Loki)? resource review against the 4 GiB cap.
- **JS-CR-1/2/3** — Jenkins authorization model, docker socket in the default agent template,
  `JENKINS_HOME` persistence.
