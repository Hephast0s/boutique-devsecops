# 06 — Secrets Management (Vault + External Secrets Operator)

## Flow

```
 Vault (KV v2 mount `boutique/`)
   │  k8s auth (role `boutique`, policy `boutique-read`)
   ▼
 External Secrets Operator (v2.9.0, pre-existing)
   │  per-namespace SecretStore `boutique-vault`
   ▼
 Kubernetes Secret  (name convention: *-eso, label managed-by=external-secrets)
   │
   ▼
 consuming pod
```

No secret value is stored in Git. CI secrets live in Jenkins/Kubernetes credentials; runtime secrets flow
Vault → ESO → Kubernetes Secret.

## Vault layout (all new, scoped; existing `secret/` untouched)

| Path | Contents | Consumers |
|---|---|---|
| `boutique/dev/redis` | `connection_string` | cartservice (via ESO) |
| `boutique/dev/app` | `session_key` (placeholder) | frontend |
| `boutique/ci/cosign` | `password`, `key_b64` | Jenkins cosign signing |
| `boutique/harbor/pull` | `username`, `password` | cluster imagePullSecret |

## Policy (`boutique-read`)

```hcl
path "boutique/data/*"     { capabilities = ["read"] }
path "boutique/metadata/*" { capabilities = ["read","list"] }
```

Least privilege: read-only on this project's data; nothing else. There is **no** capability on `secret/`,
`sys/`, or `auth/`.

## Kubernetes auth

- Auth method `kubernetes/` enabled and configured with a reviewer JWT
  (`system:auth-delegator` via ClusterRoleBinding `boutique-vault-auth-delegator`) and the cluster CA.
- Role `boutique`: `bound_service_account_namespaces = boutique-dev,boutique-staging,boutique-prod,boutique-security`,
  `bound_service_account_names = *`, `policies = boutique-read`, `ttl = 1h`.

## ESO ownership rule (lesson from the operator's previous project)

An ESO-managed Secret and a kustomize/Helm-managed Secret must **never share a name**. Convention:
ESO-managed Secrets end in `-eso` and carry `managed-by: external-secrets`. Verified:
`boutique-dev/redis-eso` is owned by ESO (`creationPolicy: Owner`).

## Rotation runbook

1. Write the new value: `vault kv put boutique/dev/redis connection_string=<new>`.
2. ESO re-syncs within `refreshInterval` (set to `1m` here).
3. Verify: `kubectl -n boutique-dev get secret redis-eso -o jsonpath='{.data.connection_string}' | base64 -d`.
4. If the consuming pod does not hot-reload, restart it (a reloader may be added later).

## Evidence (real)

- `SecretStore/boutique-vault` → `Ready=True store validated`.
- `ExternalSecret/redis-eso` → `Ready=True secret synced`; secret value `redis-cart:6379`.
- **Rotation:** changed Vault to `redis-cart:6379-rotated`; the k8s Secret updated within ~10s.
- **Cross-namespace denial:** a token minted via the `boutique` role can read `boutique/data/dev/redis`
  but is **denied** on `secret/foo` and `sys/mounts`.
- **No secret material in Git:** scan for key/token patterns returns only filename references.

## Honest limitations

- Vault is currently accessed for setup with its **root token** (stored in the vault-0 pod); the
  operator should rotate it and use scoped admin tokens. Raised as a change request.
- The cosign key still also exists as the k8s secret `boutique-ci/cosign-key`; migrating CI to the
  Vault-backed `*-eso` secret is the next step (Jenkins reads credentials by ID).
- No automatic pod restart on rotation yet (no reloader installed).
