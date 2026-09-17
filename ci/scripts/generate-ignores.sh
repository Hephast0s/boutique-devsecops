#!/usr/bin/env bash
# Generate tool ignore files FROM security/exceptions.yaml (never hand-edit the ignores).
set -euo pipefail
python3 - <<'PY'
import yaml
d = yaml.safe_load(open('security/exceptions.yaml')) or {}
ex = d.get('exceptions') or []
trivy, gitleaks, semgrep = [], [], []
for e in ex:
    t = (e.get('type') or '').lower()
    ident = e.get('identifier', '')
    if t == 'cve':
        trivy.append(ident)
    elif t == 'secret':
        gitleaks.append(ident)
    elif t == 'semgrep':
        semgrep.append(ident)
open('.trivyignore', 'w').write('\n'.join(trivy) + ('\n' if trivy else ''))
open('.gitleaksignore', 'w').write('\n'.join(gitleaks) + ('\n' if gitleaks else ''))
open('.semgrepignore', 'w').write('\n'.join(semgrep) + ('\n' if semgrep else ''))
print(f"generated: trivy={len(trivy)} gitleaks={len(gitleaks)} semgrep={len(semgrep)}")
PY
