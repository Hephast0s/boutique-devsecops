#!/usr/bin/env bash
# pre-commit guard: block files that commonly carry secrets or local credentials.
# Receives the staged file list as arguments.
set -euo pipefail

blocked=0
for f in "$@"; do
  base="$(basename "$f")"
  case "$base" in
    *.kubeconfig|kubeconfig|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*|id_ecdsa*|.env|.env.*|*.tfvars|gha-creds-*.json|*credentials*.json)
      echo "forbidden-files: refusing to commit secret-like file: $f" >&2
      blocked=1
      ;;
  esac
done

if [[ "${blocked}" -ne 0 ]]; then
  echo "forbidden-files: unstage these files (git rm --cached <file>) or add a justified allowlist entry." >&2
  exit 1
fi
