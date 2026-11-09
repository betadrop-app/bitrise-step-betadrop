#!/usr/bin/env bash
# Usage: BETADROP_CLI="node /path/to/betadrop-cli/dist/bd.js" TOKEN=bd_live_… FIXTURES=/dir tests/run.sh
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do case "$1" in --key) k="$2"; shift 2;; --value) v="$2"; shift 2;; *) shift;; esac; done\necho "$k=$v" >> "%s/env"\n' "$tmp" > "$tmp/bin/envman"
chmod +x "$tmp/bin/envman"
pass=0; fail=0
check() { # label expect(ok|err) pattern env...
  local label="$1" expect="$2" pat="$3"; shift 3
  : > "$tmp/env"
  out="$(env PATH="$tmp/bin:$PATH" "$@" ${STEP_BASH:-bash} "$here/step.sh" 2>&1)"; rc=$?
  ok=1
  [ "$expect" = ok ] && [ $rc -ne 0 ] && ok=0
  [ "$expect" = err ] && [ $rc -eq 0 ] && ok=0
  printf '%s\n' "$out" | cat - "$tmp/env" | grep -qE "$pat" || ok=0
  if [ $ok -eq 1 ]; then echo "  ok    $label"; pass=$((pass+1)); else echo "  FAIL  $label (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/      | /'; fail=$((fail+1)); fi
}
common=( api_token="$TOKEN" BETADROP_CLI="$BETADROP_CLI" BETADROP_API_URL="${BETADROP_API_URL:-}" BETADROP_APP_URL="${BETADROP_APP_URL:-}" )
check "publishes and exports the link" ok 'BETADROP_INSTALL_URL=http' "${common[@]}" file_path="$FIXTURES/adhoc.ipa" notes="bitrise" expires_in_days=3
check "a failing install check uploads nothing" err 'failed the install check' "${common[@]}" file_path="$FIXTURES/appstore.ipa" inspect=true
check "two builds in the path are refused" err 'lists 2 files' "${common[@]}" file_path="$FIXTURES/adhoc.ipa|$FIXTURES/adhoc2.ipa"
check "a bad limit is refused before upload" err 'max_devices must be a whole number' "${common[@]}" file_path="$FIXTURES/adhoc.ipa" max_devices=abc
check "a missing token is refused" err 'api_token is empty' api_token= BETADROP_CLI="$BETADROP_CLI" file_path="$FIXTURES/adhoc.ipa"
echo "$pass passed, $fail failed"
rm -rf "$tmp"
[ $fail -eq 0 ]
