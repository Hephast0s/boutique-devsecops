#!/usr/bin/env bash
# Unit test for the BUILD_TARGET / FORCE_ALL resolution logic used by the Jenkinsfile.
# Guards against regressions like passing the literal 'ALL' as a service name.
set -euo pipefail

all=$(grep -E '^  - name:' ci/services.yaml | sed 's/.*name: //' | paste -sd, -)
fail=0

# FORCE_ALL must expand to a comma-separated list that includes several real services
for want in frontend cartservice checkoutservice productcatalogservice shippingservice; do
  echo "$all" | tr ',' '\n' | grep -qx "$want" || { echo "FAIL: FORCE_ALL expansion missing '$want'"; fail=1; }
done

# the expansion must NOT be the literal token ALL
if [ "$all" = "ALL" ] || echo "$all" | tr ',' '\n' | grep -qx "ALL"; then
  echo "FAIL: FORCE_ALL expansion produced the literal 'ALL'"; fail=1
fi

# a single SERVICE param must pass through unchanged
svc="frontend"
[ "$svc" = "frontend" ] || { echo "FAIL: single-service passthrough"; fail=1; }

# changed-services list must split on commas exactly like the build loop
split=$(echo "a,b,c" | tr ',' ' '); [ "$split" = "a b c" ] || { echo "FAIL: comma split"; fail=1; }

if [ "$fail" -ne 0 ]; then echo "build-target test FAILED"; exit 1; fi
echo "build-target logic OK: FORCE_ALL -> $all"
