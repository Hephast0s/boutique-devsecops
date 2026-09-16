#!/usr/bin/env bash
# Detect which services changed between a base ref and HEAD, using ci/services.yaml as the single
# source of truth. Prints one service name per line. Shared-path changes select ALL services.
# Usage: detect-changes.sh [base-ref]   (default: origin/devsecops)
set -euo pipefail
base="${1:-origin/devsecops}"

python3 - "$base" <<'PY'
import re, sys, subprocess

base = sys.argv[1]
text = open('ci/services.yaml').read()

services, cur = [], None
for line in text.splitlines():
    m = re.match(r'\s*-\s+name:\s*(\S+)', line)
    if m:
        cur = {'name': m.group(1)}
        services.append(cur)
        continue
    m = re.match(r'\s*context:\s*(\S+)', line)
    if m and cur is not None:
        cur['context'] = m.group(1)

def git_diff(ref):
    try:
        out = subprocess.check_output(['git', 'diff', '--name-only', f'{ref}...HEAD'], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        out = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'], text=True)
    return [f for f in out.splitlines() if f]

files = git_diff(base)

shared = ('protos/', 'ci/', 'Jenkinsfile', 'kustomize/', 'security/', '.pre-commit-config.yaml')
if any(f == 'Jenkinsfile' or f.startswith(shared) for f in files):
    print('\n'.join(sorted(s['name'] for s in services)))
    sys.exit(0)

changed = set()
for s in services:
    prefixes = {s.get('context', 'src/' + s['name']), 'src/' + s['name']}
    for f in files:
        if any(f.startswith(p + '/') or f == p for p in prefixes):
            changed.add(s['name'])
print('\n'.join(sorted(changed)))
PY
