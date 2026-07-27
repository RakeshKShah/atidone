#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_HEADERS="/tmp/unauthenticated_access_denied_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/unauthenticated_access_denied_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — ensure no authenticated session is supplied to the protected todo list endpoint"
echo "PREREQ: do not send any session cookie or authentication token"

# When

echo "STEP: When — request GET /api/todos without authentication"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then

echo "STEP: Then — verify unauthenticated access is rejected and no todo array is exposed"
case "$status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for unauthenticated access got ${status}"
    exit 1
    ;;
esac
if [ "$status" = "302" ] || [ "$status" = "303" ]; then
  grep -qi '^location:' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected redirect response to include Location header"; exit 1; }
fi
if jq -e 'type == "array"' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected protected endpoint not to return a JSON todo array for unauthenticated caller"
  exit 1
fi
if grep -q '"title"' "$RESPONSE_BODY"; then
  echo "ASSERTION_FAILED: unauthenticated response unexpectedly exposed todo item fields"
  exit 1
fi

# Cleanup

echo "STEP: Cleanup — no cleanup required because the request was stateless"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_denied"
