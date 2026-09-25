#!/usr/bin/env bash
# Emit sensible `--exclude-rule=` flags for every `type: semgrep` entry in
# security/exceptions.yaml. Keeps the Semgrep gate honest: accepted rules must be
# registered (with owner + expiry) before the gate can ignore them.
set -euo pipefail
python3 - <<'PY'
import re
s = open('security/exceptions.yaml').read()
ids = re.findall(r'type:\s*semgrep\s*\n\s*identifier:\s*"?([^"\n]+)"?', s)
for i in ids:
    print('--exclude-rule=' + i.strip())
PY
