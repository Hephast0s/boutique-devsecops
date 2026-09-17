#!/usr/bin/env bash
# Smoke test for an Online Boutique environment. Fails fast on the first broken check.
# Usage: smoke.sh <base-url>   e.g. smoke.sh http://boutique-dev.192.168.1.8.nip.io
set -euo pipefail
BASE="${1:?usage: smoke.sh <base-url>}"
CJ="$(mktemp)"; trap 'rm -f "$CJ"' EXIT
pass=0; fail=0
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then echo "PASS  $1 ($3)"; pass=$((pass+1)); else echo "FAIL  $1 (expected $2, got $3)"; fail=$((fail+1)); fi
}

code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$BASE/_healthz");                 check "healthz"       200 "$code"
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' -c "$CJ" "$BASE/");                check "home"          200 "$code"
home=$(curl -s -m 10 -b "$CJ" -c "$CJ" "$BASE/")
pid=$(grep -oE '/product/[A-Z0-9]+' <<<"$home" | head -1 | cut -d/ -f3)
[[ -n "$pid" ]] && echo "PASS  product link found ($pid)" && pass=$((pass+1)) || { echo "FAIL  no product link"; fail=$((fail+1)); }
code=$(curl -s -o /dev/null -m 10 -b "$CJ" -c "$CJ" -w '%{http_code}' "$BASE/product/$pid"); check "product page" 200 "$code"
code=$(curl -s -o /dev/null -m 10 -b "$CJ" -c "$CJ" -X POST --data "product_id=$pid&quantity=1" -w '%{http_code}' "$BASE/cart"); check "add to cart" 302 "$code"
code=$(curl -s -o /dev/null -m 10 -b "$CJ" -c "$CJ" -X POST --data 'currency_code=EUR' -w '%{http_code}' "$BASE/setCurrency"); check "set currency" 302 "$code"
out=$(curl -s -m 15 -b "$CJ" -c "$CJ" -X POST \
  --data-urlencode 'email=smoke@example.com' --data-urlencode 'street_address=1 Smoke St' \
  --data-urlencode 'zip_code=12345' --data-urlencode 'city=Cairo' --data-urlencode 'state=CA' \
  --data-urlencode 'country=EG' --data-urlencode 'credit_card_number=4111111111111111' \
  --data-urlencode 'credit_card_expiration_month=12' --data-urlencode 'credit_card_expiration_year=2030' \
  --data-urlencode 'credit_card_cvv=123' "$BASE/cart/checkout")
grep -q 'Your order' <<<"$out" && { echo "PASS  checkout"; pass=$((pass+1)); } || { echo "FAIL  checkout"; fail=$((fail+1)); }

echo "---- $BASE : pass=$pass fail=$fail ----"
[[ "$fail" -eq 0 ]]
