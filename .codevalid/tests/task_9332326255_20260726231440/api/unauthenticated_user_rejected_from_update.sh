#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_rejected_from_update"
TODO_ID="todo-456-${CASE_SUFFIX}"
OWNER_USER_ID="user-owner-${CASE_SUFFIX}"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
DB_RESULT="/tmp/${TEST_ID}_db_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$PATCH_HEADERS" "$PATCH_BODY" "$DB_RESULT" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — create todo fixture without authenticating requester"
echo "PREREQ: inserting todo ${TODO_ID} with owner ${OWNER_USER_ID}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
INSERT INTO todos (id, user_id, title, completed) VALUES ('${TODO_ID}', '${OWNER_USER_ID}', 'Unauth fixture ${CASE_SUFFIX}', 0);
SQL

cat > "$REQUEST_BODY_FILE" <<JSON
{"completed":true}
JSON

echo "STEP: When — PATCH todo without authentication cookies or session"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
PATCH_CODE="$(curl -sS -X PATCH \
  -H 'Content-Type: application/json' \
  -D "$PATCH_HEADERS" \
  -o "$PATCH_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/${TODO_ID}" \
  --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_HEADERS:"
cat "$PATCH_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH_BODY"
echo "RESPONSE_STATUS: ${PATCH_CODE}"

echo "STEP: Then — assert unauthenticated request is rejected and row unchanged"
[ "$PATCH_CODE" = "401" ] || { echo "ASSERTION_FAILED: expected HTTP 401 got ${PATCH_CODE}"; exit 1; }
grep -F '401' "$PATCH_BODY" >/dev/null || grep -F 'Unauthorized' "$PATCH_BODY" >/dev/null || grep -F 'auth' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to indicate unauthorized access"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT completed FROM todos WHERE id = '${TODO_ID}' AND user_id = '${OWNER_USER_ID}';" > "$DB_RESULT"
DB_VALUE="$(cat "$DB_RESULT")"
[ "$DB_VALUE" = "0" ] || { echo "ASSERTION_FAILED: expected todo to remain completed=0 but got ${DB_VALUE}"; exit 1; }

echo "STEP: Cleanup — delete seeded todo row"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM todos WHERE id = '${TODO_ID}';"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_rejected_from_update"
