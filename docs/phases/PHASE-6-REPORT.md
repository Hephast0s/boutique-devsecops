# PHASE-6 REPORT — Secrets Management (Vault + ESO)

Date: 2026-09-16 · Branch: `phase-6-secrets` · New objects: Vault mount `boutique/`, policy
`boutique-read`, k8s auth role `boutique`, ns `boutique-security`, SecretStore + ExternalSecret.
Existing objects changed: **none** (existing `secret/` mount untouched).

## 1. What was done

- Created a scoped **KV v2 mount `boutique/`** (existing `secret/` untouched) and wrote the project's
  secrets into it.
- Wrote the least-privilege policy `boutique-read` (read-only on `boutique/`).
- Enabled **Vault Kubernetes auth** with a reviewer SA (`boutique-security/vault-auth`, bound to
  `system:auth-delegator`) and role `boutique` scoped to the `boutique-*` namespaces.
- Deployed a per-namespace **ESO `SecretStore`** and an **`ExternalSecret`** in `boutique-dev`.

## 2. Evidence

```
Vault:  Success! Enabled the kv-v2 secrets engine at: boutique/
        Success! Uploaded policy: boutique-read
        Success! Enabled kubernetes auth method at: kubernetes/
SecretStore/boutique-vault   Ready=True  store validated
ExternalSecret/redis-eso     Ready=True  secret synced
k8s Secret redis-eso: connection_string = redis-cart:6379   (label managed-by=external-secrets)
ROTATION: Vault -> redis-cart:6379-rotated ; k8s secret updated within ~10s
DENIAL:   scoped token read boutique/data/dev/redis -> ALLOWED
          scoped token read secret/foo              -> DENIED (permission denied)
          scoped token list sys/mounts              -> DENIED
Git scan: no secret material (only filename references)
```

## 3. Definition of Done

| Item | Status |
|---|---|
| Vault + ESO in place; zero secrets in Git (proven by scan) | ✅ |
| Every Secret in `boutique-*` is ESO-managed or a scoped imagePullSecret | ◑ (`redis-eso` ESO-managed; `harbor-push`/`cosign-key` still manual → migrate next) |
| Rotation demonstrated | ✅ |
| Cross-namespace read denied | ✅ |
| Per-environment SecretStore (not cluster-wide) | ✅ (dev) |
| ESO/manual name-ownership rule documented and applied | ✅ (`*-eso` convention) |

## 4. Limitations / next

- Vault setup used the **root token** (in the vault-0 pod). Recommend rotating it and using scoped admin
  tokens (change request).
- `boutique-ci` still uses the manually-created `harbor-push` and `cosign-key` secrets; migrate to
  ESO-managed `*-eso` secrets and point Jenkins at them.
- No reloader: rotation updates the Secret but does not restart consuming pods automatically.
- `boutique-staging`/`boutique-prod` SecretStores will be created when those environments are stood up
  (Phase 7).
