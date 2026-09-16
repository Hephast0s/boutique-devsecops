# Contributing

## Branching

Trunk-based with short-lived branches. The `main` branch is protected (linear history, required PR,
required status checks).

- Work happens on a branch per work-stream, named after the phase/feature (`phase-2-git-controls`,
  `feat/...`, `fix/...`, `security/...`).
- Integration branch `devsecops` accumulates phase work; a final integrated branch is cut at the end.
- Never commit directly to `main`. Open a PR; a green pipeline is required to merge.
- Rebase onto the base branch before merging; merge commits are not accepted on feature branches.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) are enforced by the `commit-msg` hook:

```
<type>(<scope>): <description>
```

Allowed types: `build chore ci docs feat fix perf refactor revert style test security`.

Commits are GPG-signed. See `docs/02-signing-identities.md` for the identity model (human vs CI bot).

## Pre-commit

Install and run the hooks before pushing:

```bash
pipx install pre-commit
pre-commit install --hook-type pre-commit --hook-type commit-msg
pre-commit run --all-files
```

The hooks scan for secrets (gitleaks), lint Dockerfiles (hadolint), validate YAML, shell, Markdown and
Python, and block secret-like filenames.

## Pull requests

Use the PR template. Every PR must include evidence (real command output) and a rollback note. Security-
sensitive paths (`security/`, `ci/`, the Jenkinsfile) require the CODEOWNER's review.

## Definition of done

- Pre-commit passes.
- Pipeline is green (once Jenkins is wired).
- Documentation updated, including `docs/CHANGE_LOG.md` for any created/changed object.
- No secret material anywhere.
