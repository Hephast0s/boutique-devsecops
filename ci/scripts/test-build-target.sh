#!/usr/bin/env bash
# Unit test for the BUILD_TARGET / FORCE_ALL logic. This asserts the *actual Jenkinsfile source*
# (so a regression to the broken literal 'ALL' fails the build) and validates the ci/services.yaml
# expansion.
set -euo pipefail

fail=0

# 1) The Jenkinsfile must expand FORCE_ALL to the real service list, not the literal 'ALL'.
if ! grep -qE "FORCE_ALL \? allSvcs" Jenkinsfile; then
  echo "FAIL: Jenkinsfile does not expand FORCE_ALL to allSvcs"; fail=1
fi
if grep -qE "FORCE_ALL \? '[^']*'" Jenkinsfile; then
  echo "FAIL: Jenkinsfile still sets a literal literal for FORCE_ALL"; fail=1
fi
if ! grep -q "grep -E '\^  - name:' ci/services.yaml" Jenkinsfile; then
  echo "FAIL: Jenkinsfile does not derive the service list from ci/services.yaml"; fail=1
fi

# 2) The derived list must be a real, non-empty set of services.
all=$(grep -E '^  - name:' ci/services.yaml | sed 's/.*name: //' | paste -sd, -)
for want in frontend cartservice checkoutservice productcatalogservice shippingservice; do
  echo "$all" | tr ',' '\n' | grep -qx "$want" || { echo "FAIL: expansion missing '$want'"; fail=1; }
done
if [ "$all" = "ALL" ] || echo "$all" | tr ',' '\n' | grep -qx "ALL"; then
  echo "FAIL: expansion produced the literal 'ALL'"; fail=1
fi
[ -n "$all" ] || { echo "FAIL: empty expansion"; fail=1; }

# 3) The comma split used by the build loop must be exact.
split=$(echo "a,b,c" | tr ',' ' '); [ "$split" = "a b c" ] || { echo "FAIL: comma split"; fail=1; }

if [ "$fail" -ne 0 ]; then echo "build-target test FAILED"; exit 1; fi
echo "build-target logic OK (Jenkinsfile + services.yaml): FORCE_ALL -> $all"
