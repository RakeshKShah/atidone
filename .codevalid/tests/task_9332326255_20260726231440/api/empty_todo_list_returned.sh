#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
USER_ID="user-nodata-${CASE_SUFFIX}"
SESSION_COOKIE_VALUE="%7B%22user%22%3A%7B%22id%22%3A%22${USER_ID}%22%7D%7D"

RESPONSE_HEADERS="/tmp/empty_todo_list_returned_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/empty_todo_list_returned_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — ensure the authenticated user has no todos"
echo "PREREQ: deleting any rows for the generated user id"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
SQL

# When
echo "STEP: When — call GET /api/todos for an authenticated user with no data"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: nuxt-session=${SESSION_COOKIE_VALUE}"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -H "Cookie: nuxt-session=${SESSION_COOKIE_VALUE}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then
echo "STEP: Then — verify the API returns an empty JSON array"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
body_compact="$(tr -d '[:space:]' < "$RESPONSE_BODY")"
[ "$body_compact" = "[]" ] || { echo "ASSERTION_FAILED: expected empty JSON array [] got ${body_compact}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — delete any rows for the generated user id"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:empty_todo_list_returned"
