# Runbook — Secret leak

1. **Contain:** revoke the leaked credential at its source (Gmail app password, Harbor robot, Vault token,
   Jenkins credential). Rotate immediately.
2. **Assess scope:** `gitleaks git .` across history; check Jenkins build logs for the value; check whether
   it ever entered Git (`git log -S`).
3. **Rotate in Vault:** `vault kv put boutique/<path> ...`; ESO re-syncs within `refreshInterval` (~1m).
   Confirm: `kubectl -n boutique-<env> get secret <name>-eso -o jsonpath='{.data...}'`.
4. **Restart consumers** that do not hot-reload: `kubectl -n boutique-<env> rollout restart deploy/<svc>`.
5. **If it reached Git:** treat history as compromised; rotate first, then consider history rewrite
   (requires operator decision; this engagement never rewrites history).
6. **Post-incident:** add an exception or a gitleaks rule if it was a false positive; write it up in
   `docs/ISSUES.md`.
