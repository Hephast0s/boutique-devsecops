# 02 — Signing Identities

Two distinct identities sign different things. This file is the source of truth for both, including
revocation.

## Status

| Identity | Purpose | Key | Status |
|---|---|---|---|
| Human (operator) | signs human commits + release tags | `gpg_key_id`: **MISSING** (operator has no GPG secret key on this host) | **pending operator** |
| CI bot | signs CI commits that write digest pins to the GitOps layer | dedicated key generated for this engagement | to be generated in Phase 5 |

Verified during Phase 1: `gpg --list-secret-keys` on the host is **empty**. The engagement therefore
**cannot** produce human-signed commits yet, and must not fabricate a key claiming the operator's identity.

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
