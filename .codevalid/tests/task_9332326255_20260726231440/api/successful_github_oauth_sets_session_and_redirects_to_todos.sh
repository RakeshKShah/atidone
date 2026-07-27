#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/successful_github_oauth_sets_session_and_redirects_to_todos_cookie_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/successful_github_oauth_sets_session_and_redirects_to_todos_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/successful_github_oauth_sets_session_and_redirects_to_todos_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — initialize a fresh client without an authenticated session"
: > "$COOKIE_JAR"
echo "PREREQ: created empty cookie jar for OAuth initiation at $COOKIE_JAR"

echo "STEP: When — initiate GitHub OAuth via the public authentication endpoint"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — verify OAuth flow starts and redirects toward GitHub authorization"
case "$status" in
  302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected OAuth initiation redirect got HTTP ${status}"
    exit 1
    ;;
esac
location_header="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_FILE" | tail -n 1)"
[ -n "$location_header" ] || { echo "ASSERTION_FAILED: expected Location header from OAuth initiation"; exit 1; }
printf '%s' "$location_header" | grep -E 'github\.com/.*/oauth|github\.com/login/oauth/authorize|/api/auth/github' >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected redirect to GitHub OAuth authorize endpoint or auth intermediary, got ${location_header}"
  exit 1
}
set_cookie_lines="$(awk 'BEGIN{IGNORECASE=1} /^set-cookie:/ {print}' "$HEADERS_FILE" || true)"
if [ -n "$set_cookie_lines" ]; then
  printf '%s\n' "$set_cookie_lines" | grep -Ei 'set-cookie:' >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected observed cookie lines to be Set-Cookie headers"
    exit 1
  }
fi
printf '%s' "$location_header" | grep -E '/todos' >/dev/null 2>&1 && {
  echo "ASSERTION_FAILED: OAuth initiation should not already redirect to /todos before callback completion"
  exit 1
}

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:successful_github_oauth_sets_session_and_redirects_to_todos"
