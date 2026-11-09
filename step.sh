#!/usr/bin/env bash
# BetaDrop Upload for Bitrise. A thin wrapper over @betadrop/cli, so this step, the GitHub Action
# and a developer's terminal run the same client and behave the same way.
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -n "${api_token:-}" ] || fail "api_token is empty. Add a BetaDrop API token as a Secret and pass it in."
export BETADROP_TOKEN="$api_token"

# Android Build exports a pipe-separated list; take it apart and insist on exactly one build.
path="$(printf '%s' "${file_path:-}" | tr '|' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' || true)"
count="$(printf '%s\n' "$path" | grep -c . || true)"
[ "$count" -ge 1 ] || fail "file_path is empty. Point it at the .ipa or .apk an earlier step produced."
[ "$count" -eq 1 ] || fail "file_path lists $count files; set it to exactly one build."
[ -f "$path" ] || fail "No build at '$path'."

# BETADROP_CLI lets the step's own tests run a local build of the CLI; a workflow never sets it.
if [ -n "${BETADROP_CLI:-}" ]; then
  cli=( $BETADROP_CLI )
else
  command -v npx >/dev/null 2>&1 || fail "Node.js is not available on this stack."
  cli=( npx --yes "@betadrop/cli@${cli_version:-0.4.0}" )
fi

number() {
  local name="$1" value="$2"
  [ -z "$value" ] && return 0
  case "$value" in
    *[!0-9]*|0*) fail "$name must be a whole number of 1 or more (got '$value')." ;;
  esac
}
number expires_in_days "${expires_in_days:-}"
number max_downloads "${max_downloads:-}"
number max_devices "${max_devices:-}"

if [ "${inspect:-false}" = "true" ]; then
  echo "Checking $(basename "$path") will install from a link"
  "${cli[@]}" inspect "$path" || fail "$(basename "$path") failed the install check, so nothing was uploaded."
fi

args=( publish "$path" --ci )
[ -n "${notes:-}" ] && args+=( --notes "$notes" )
[ -n "${standing_link:-}" ] && args+=( --standing-link "$standing_link" )
[ -n "${expires_in_days:-}" ] && args+=( --expires-in-days "$expires_in_days" )
[ -n "${max_downloads:-}" ] && args+=( --max-downloads "$max_downloads" )
[ -n "${max_devices:-}" ] && args+=( --max-devices "$max_devices" )

log="$(mktemp)"
set +e
"${cli[@]}" "${args[@]}" | tee "$log"
status=${PIPESTATUS[0]}
set -e
[ "$status" -eq 0 ] || fail "betadrop publish failed (exit $status); its message is above."

url="$(tail -n 1 "$log")"
standing="$(grep -m1 '^channel-url=' "$log" | cut -d= -f2- || true)"
case "$url" in https://*|http://*) ;; *) fail "Publish did not end with an install link (last line: $url)." ;; esac

envman add --key BETADROP_INSTALL_URL --value "$url"
envman add --key BETADROP_STANDING_LINK_URL --value "$standing"
echo "Install link: $url"
[ -n "$standing" ] && echo "Standing link: $standing"
exit 0
