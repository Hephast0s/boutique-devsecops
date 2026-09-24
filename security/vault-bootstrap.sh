#!/usr/bin/env bash
# Re-seed Vault for the Online Boutique project.
#
# WHY THIS EXISTS: the pre-existing Vault release uses an emptyDir for storage
# (non-persistent), so every Vault restart WIPES the boutique/ mount, the
# kubernetes auth method and the secrets. ExternalSecret then fails with
# "could not get secret data from provider" until this is re-run.
# Root cause + change request: docs/CHANGE_REQUESTS.md (CR-VAULT-PERSISTENCE).
#
# Run after any Vault restart. Idempotent.
set -euo pipefail

VE() { kubectl -n vault exec vault-0 -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 $*"; }

echo "== enabling boutique KV v2 mount =="
VE 'vault secrets enable -path=boutique kv-v2' || true

echo "== restoring secrets from the live Kubernetes Secrets (source of truth at runtime) =="
R=$(kubectl -n boutique-dev get secret redis-eso -o jsonpath='{.data.connection_string}' 2>/dev/null | base64 -d || true)
VE "vault kv put boutique/dev/redis connection_string='${R:-redis-cart:6379}'"
U=$(kubectl -n boutique-dev get secret smtp-eso -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)
P=$(kubectl -n boutique-dev get secret smtp-eso -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
[ -n "$U" ] && VE "vault kv put boutique/dev/smtp username='$U' password='$P'" || echo "  (smtp-eso empty; set Gmail app password via vault kv put)"
CP=$(kubectl -n boutique-ci get secret cosign-key -o jsonpath='{.data.COSIGN_PASSWORD}' 2>/dev/null | base64 -d || true)
if [ -n "$CP" ] && [ -f security/cosign.key ]; then
  B64=$(base64 -w0 security/cosign.key)
  VE "vault kv put boutique/ci/cosign password='$CP' key_b64='$B64'"
fi

echo "== policy boutique-read =="
kubectl -n vault exec -i vault-0 -- sh -c 'VAULT_ADDR=http://127.0.0.1:8200 vault policy write boutique-read -' <<'EOF'
path "boutique/data/*" { capabilities = ["read"] }
path "boutique/metadata/*" { capabilities = ["read","list"] }
EOF

echo "== kubernetes auth =="
JWT=$(kubectl create token vault-auth -n boutique-security --duration=87600h)
kubectl -n boutique-security get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' | kubectl -n vault exec -i vault-0 -- sh -c 'cat > /tmp/ca.crt'
VE 'vault auth enable kubernetes' || true
VE "vault write auth/kubernetes/config token_reviewer_jwt='$JWT' kubernetes_host='https://kubernetes.default.svc' kubernetes_ca_cert=@/tmp/ca.crt"
VE "vault write auth/kubernetes/role/boutique bound_service_account_names='*' bound_service_account_namespaces='boutique-dev,boutique-staging,boutique-prod,boutique-security' policies='boutique-read' ttl='1h'"

echo "== nudge External Secrets =="
kubectl -n boutique-dev annotate secretstore boutique-vault force-sync="$(date +%s)" --overwrite >/dev/null
kubectl -n boutique-dev annotate externalsecret redis-eso smtp-eso force-sync="$(date +%s)" --overwrite >/dev/null
sleep 15
kubectl -n boutique-dev get externalsecret -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status'
echo "done."
