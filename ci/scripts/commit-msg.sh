#!/usr/bin/env bash
# commit-msg hook: enforce Conventional Commits.
# Usage: commit-msg.sh <path-to-COMMIT_EDITMSG>
set -euo pipefail

msg_file="${1:-}"
if [[ -z "${msg_file}" || ! -f "${msg_file}" ]]; then
  echo "commit-msg: no commit message file provided" >&2
  exit 1
fi

# First non-comment, non-empty line
subject="$(grep -vE '^\s*#' "${msg_file}" | sed '/^\s*$/d' | head -n1)"

pattern='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test|security)(\([a-z0-9._/-]+\))?(!)?: .{1,}'

if [[ ! "${subject}" =~ ${pattern} ]]; then
  echo "commit-msg: message does not follow Conventional Commits." >&2
  echo "  got:      ${subject}" >&2
  echo "  expected: <type>(<scope>)?: <description>" >&2
  echo "  types:    build chore ci docs feat fix perf refactor revert style test security" >&2
  exit 1
fi

# Reject merge commits in the subject unless explicitly a revert
if [[ "${subject}" =~ ^Merge ]]; then
  echo "commit-msg: merge commits are not allowed on feature branches (rebase instead)." >&2
  exit 1
fi
