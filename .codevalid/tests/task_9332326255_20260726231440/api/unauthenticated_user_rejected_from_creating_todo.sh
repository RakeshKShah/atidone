#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_rejected_from_creating_todo"
WHEN_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$WHEN_HEADERS" "$WHEN_BODY" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<'JSON'
{"title":"Test todo"}
JSON

echo "STEP: Given — ensure request is sent without any authenticated session"
echo "PREREQ: no cookie jar or authorization header will be provided"

echo "STEP: When — send unauthenticated POST /api/todos"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$(curl -sS -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' --data-binary @"$REQUEST_BODY_FILE")"
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

echo "STEP: Then — assert unauthenticated request is rejected"
case "$code" in
  401|302|303|500) : ;;
  *)
    echo "ASSERTION_FAILED: expected unauthenticated rejection HTTP 401/302/303/500 got ${code}"
    exit 1
    ;;
esac
if [ "$code" = "200" ] || [ "$code" = "201" ]; then
  echo "ASSERTION_FAILED: unauthenticated request unexpectedly created a todo"
  exit 1
fi

echo "STEP: Cleanup — no stateful setup to undo"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_rejected_from_creating_todo"
