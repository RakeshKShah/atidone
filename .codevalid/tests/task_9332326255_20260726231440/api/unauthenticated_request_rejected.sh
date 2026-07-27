#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_HEADERS="/tmp/unauthenticated_request_rejected_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/unauthenticated_request_rejected_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — prepare an unauthenticated request with no session cookie or auth token"
echo "PREREQ: no authenticated session is created for this test case"

# When

echo "STEP: When — send GET /api/todos without any authentication credentials"
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

echo "STEP: Then — verify the unauthenticated request is rejected and no todo data is returned"
case "$status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for unauthenticated request got ${status}"; exit 1 ;;
esac
if [ "$status" = "401" ]; then
  if jq -e 'type == "array"' "$RESPONSE_BODY" >/dev/null 2>&1; then
    echo "ASSERTION_FAILED: expected no todo array payload for unauthenticated request"
    exit 1
  fi
else
  grep -Eq 'signin|sign-in|login|auth|unauth|error|redirect' "$RESPONSE_BODY" "$RESPONSE_HEADERS" || {
    echo "ASSERTION_FAILED: expected redirect/authentication signal in headers or body for status ${status}"
    exit 1
  }
fi

# Cleanup

echo "STEP: Cleanup — no cleanup required because this test is stateless"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_request_rejected"
