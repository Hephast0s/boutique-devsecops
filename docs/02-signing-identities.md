# 02 — Signing Identities

Two distinct identities sign different things. This file is the source of truth for both, including
revocation.

## Status

| Identity | Purpose | Key | Status |
|---|---|---|---|
| Human (operator) | signs human commits + release tags | `gpg_key_id`: **MISSING** (operator has no GPG secret key on this host) | **pending operator** |
| CI bot | signs commits while no human key exists; later signs CI digest-pin commits | `84DF9F67AAB13638` (ed25519, exp 2028-09-15), pubkey `security/gpg-ci-bot.pub` | **generated 2026-09-16** |

Verified during Phase 1: `gpg --list-secret-keys` on the host was **empty**. A dedicated engagement key was
then generated (it does **not** claim the operator's identity). Until the operator provides a key, commits
are signed with the CI-bot key; this is recorded as a temporary measure, not the final model.

## Human identity (operator)

When the operator provides a key (`gpg_signing_owner: operator`), configure:

```bash
git config --local user.signingkey <KEY_ID>
git config --local commit.gpgsign true
git config --local tag.gpgsign true
```

Export the public key for GitHub and for reviewers:

```bash
gpg --armor --export <KEY_ID> > docs/evidence/gpg-operator.pub
```

If the operator prefers to sign on their own machine, the agent will stop producing commits and hand over
the exact `git config` and commands.

## CI bot identity

- Name/email: `boutique-ci-bot <boutique-ci-bot@users.noreply.github.com>` (committed via the CI bot's
  GitHub account or a machine user).
- A dedicated GPG keypair is generated; the **private key + passphrase live in Vault** (`boutique/ci/cosign`
  and `boutique/ci/gpg`), surfaced to Jenkins as credentials by ID only — never committed, never in logs.
- The public key is published in the repo (`security/gpg-ci-bot.pub`) and uploaded to the bot's GitHub account.
- CI commits (digest pins) are signed with this key.

## Revocation

- **Compromise of the human key:** publish a signed revocation certificate, remove the key from GitHub,
  re-sign `main`'s tip going forward, and rotate any commit-derived trust.
- **Compromise of the CI bot key:** rotate the key in Vault, revoke the GitHub key, invalidate the Jenkins
  credential, and re-verify that no unsigned commit entered the GitOps layer after the compromise window.
- **Compromise of the cosign key:** see `docs/05-key-management.md`.

## Honest limitation

Until the operator supplies a key, commits authored by the agent use the CI-bot identity only where
appropriate, and the engagement records the gap rather than disabling signature verification.
