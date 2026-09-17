# PHASE-2 REPORT — Git Strategy, Repositories and Pre-Commit Controls

Date: 2026-09-16 · Branch: `phase-2-git-controls` · New repo: `github.com/Hephast0s/boutique-devsecops`

## 1. What was done

- Read-only Phase-1 discovery showed Gitea is scaled to 0, so the Gitea-first plan was replaced
  (operator decision) with **GitHub**. The original fork `MinaC4/microservices-demo` has no admin, so
  branch protection is impossible there → a **new repo** `Hephast0s/boutique-devsecops` was created.
- Branch model implemented: `main` + `devsecops` (protected) + `phase-2-git-controls` work branch;
  a final integrated branch is planned at the end.
- Enforcement: branch protection + **signed commits** via a generated CI-bot GPG key.
- Pre-commit controls and repository governance files authored.

## 2. Commands run (real)

```
gh repo create Hephast0s/boutique-devsecops --public --description "..."
git remote rename origin fork ; git remote add origin https://github.com/Hephast0s/boutique-devsecops.git
git push -u origin main ; git push -u origin devsecops ; git push -u origin phase-2-git-controls
gh api -X PUT repos/Hephast0s/boutique-devsecops/branches/{main,devsecops}/protection --input protection.json
gh api -X POST repos/Hephast0s/boutique-devsecops/branches/{main,devsecops}/protection/required_signatures
gpg --batch --passphrase '' --quick-generate-key "boutique-ci-bot <...>" ed25519 sign 2y
git config --local user.signingkey 84DF9F67AAB13638 ; git config --local commit.gpgsign true
git commit -m "..."   # signed
pre-commit run forbidden-files --files .env      # gate test
docker run --rm -v /tmp/opencode/gl-test:/scan ghcr.io/gitleaks/gitleaks:latest dir /scan --redact
```

## 3. Evidence

**Branch protection (GitHub API):**
```
main:     {"linear":true,"signed":true,"reviews":1,"force":false,"deletions":false}
devsecops:{"linear":true,"signed":true,"reviews":1,"force":false,"deletions":false}
```

**Signed commit verified (`git log --show-signature`):**
```
gpg: Good signature from "boutique-ci-bot <boutique-ci-bot@users.noreply.github.com>" [ultimate]
using EDDSA key F095C11785AE6E5DB932191484DF9F67AAB13638
commit 375c33ec...
```

**Secret-blocking gate (planted `.env`):**
```
block secret-like filenames..............................................Failed
forbidden-files: refusing to commit secret-like file: .env
```

**gitleaks detected a planted secret and exited non-zero:**
```
leaks found: 2
gitleaks_exit=1
```

## 4. Deliverables created

| File | Purpose |
|---|---|
| `.pre-commit-config.yaml` | gitleaks, hadolint, yamllint, shellcheck, markdownlint, ruff, local guards |
| `.gitleaks.toml`, `.hadolint.yaml`, `.yamllint`, `.markdownlint.json` | tool policies |
| `ci/scripts/commit-msg.sh` | Conventional Commits enforcement |
| `ci/scripts/forbidden-files.sh` | blocks secret-like filenames |
| `.github/PULL_REQUEST_TEMPLATE/devsecops.md` | PR security checklist (upstream template preserved) |
| `.github/CODEOWNERS` | additive: upstream line kept, engagement paths added |
| `SECURITY.md`, `CONTRIBUTING.md` | governance |
| `docs/02-git-strategy.md`, `docs/02-signing-identities.md` | strategy + identity model |
| `security/gpg-ci-bot.pub` | CI-bot public key |

## 5. Definition of Done

| Item | Status | Evidence |
|---|---|---|
| Repos/branches exist with initial commits | ✅ | `git ls-remote` → main/devsecops/phase-2 on new repo |
| `main` protected (PR, linear history, no force-push) | ✅ | protection JSON §3 |
| At least one verified signed commit | ✅ | `git log --show-signature` §3 |
| Pre-commit runs and blocks a planted secret | ✅ | forbidden-files failure + gitleaks exit 1 §3 |
| Pre-commit runs clean on the whole tree | ⏸ | full-suite first-run provisioning deferred (resource cap); hooks defined and demonstrated individually |
| Operator human GPG key | ⏸ BLOCKED | not provided; CI-bot key used meanwhile (documented) |

## 6. Deviations

1. Gitea dropped → GitHub (operator). 2. New repo created because the fork lacks admin. 3. Full
`pre-commit run --all-files` not executed locally (7 environments + full-history scan exceed the 4 GiB
budget); replaced with targeted hook + gitleaks-dir evidence. 4. `.github/CODEOWNERS` changed
**additively only** (upstream owner line preserved) and logged in `CHANGE_LOG.md`.

## 7. Blockers / next

- **Operator human GPG key** (`gpg_signing_owner`) — so human commits are signed by the operator.
- **Jenkins API token** (CR-007) to wire required status checks and, in Phase 4, the pipeline itself.
- Next: merge `phase-2-git-controls` → `devsecops` via PR, then Phase 3 (baseline deployment to `boutique-dev`).
