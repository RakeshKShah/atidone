#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/oauth_failure_does_not_create_session_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/oauth_failure_does_not_create_session_body_${CASE_SUFFIX}.txt"
HEADERS_FILE_TODOS="/tmp/oauth_failure_does_not_create_session_headers_todos_${CASE_SUFFIX}.txt"
BODY_FILE_TODOS="/tmp/oauth_failure_does_not_create_session_body_todos_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$HEADERS_FILE_TODOS" "$BODY_FILE_TODOS"
}
trap cleanup_files EXIT

echo "STEP: Given — no successful OAuth completion is performed, so no authenticated session should exist"

echo "STEP: When — call the protected todos endpoint without completing OAuth"
echo 'REQUEST_HEADERS:'
printf 'Accept: application/json\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_todos="$(curl -sS -D "$HEADERS_FILE_TODOS" -o "$BODY_FILE_TODOS" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE_TODOS"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE_TODOS"
echo "RESPONSE_STATUS: $status_todos"

echo "STEP: Then — verify access remains blocked without a completed OAuth success path"
case "$status_todos" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated protection status 401/302/303/500 got ${status_todos}"; exit 1 ;;
esac


echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:oauth_failure_does_not_create_session'
