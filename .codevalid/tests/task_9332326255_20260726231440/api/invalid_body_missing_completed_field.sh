#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="invalid_body_missing_completed_field"
USER_ID="user-123"
TODO_ID="todo-456-${CASE_SUFFIX}"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
DB_RESULT="/tmp/${TEST_ID}_db_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$PATCH_HEADERS" "$PATCH_BODY" "$DB_RESULT" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

SESSION_COOKIE_NAME="${SESSION_COOKIE_NAME:-nuxt-session}"
SESSION_COOKIE_VALUE="${SESSION_COOKIE_VALUE:-test-session-user-123}"
printf '%s\n' "# Netscape HTTP Cookie File" > "$COOKIE_JAR"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' app FALSE / FALSE 2147483647 "$SESSION_COOKIE_NAME" "$SESSION_COOKIE_VALUE" >> "$COOKIE_JAR"

echo "STEP: Given — create authenticated user's todo fixture for validation test"
echo "PREREQ: inserting todo ${TODO_ID} for user ${USER_ID} with completed=0"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
INSERT INTO todos (id, user_id, title, completed) VALUES ('${TODO_ID}', '${USER_ID}', 'Validation seed todo ${CASE_SUFFIX}', 0);
SQL

cat > "$REQUEST_BODY_FILE" <<JSON
{}
JSON

echo "STEP: When — PATCH todo with invalid body missing completed field"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie session prepared via ${COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
PATCH_CODE="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" \
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

echo "STEP: Then — assert validation error and unchanged todo state"
if [ "$PATCH_CODE" = "400" ] || [ "$PATCH_CODE" = "422" ]; then
  :
else
  echo "ASSERTION_FAILED: expected HTTP 400 or 422 got ${PATCH_CODE}"
  exit 1
fi
grep -F 'completed' "$PATCH_BODY" >/dev/null || grep -F 'validation' "$PATCH_BODY" >/dev/null || grep -F 'Invalid' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to mention validation failure for completed"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT id || '|' || user_id || '|' || completed FROM todos WHERE id = '${TODO_ID}';" > "$DB_RESULT"
DB_ROW="$(cat "$DB_RESULT")"
[ -n "$DB_ROW" ] || { echo "ASSERTION_FAILED: expected database row for ${TODO_ID}"; exit 1; }
printf '%s' "$DB_ROW" | grep -F "${TODO_ID}|${USER_ID}|0" >/dev/null || { echo "ASSERTION_FAILED: expected database row ${TODO_ID}|${USER_ID}|0 but got ${DB_ROW}"; exit 1; }

echo "STEP: Cleanup — delete seeded todo row"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM todos WHERE id = '${TODO_ID}';"

echo "CODEVALID_TEST_ASSERTION_OK:invalid_body_missing_completed_field"
