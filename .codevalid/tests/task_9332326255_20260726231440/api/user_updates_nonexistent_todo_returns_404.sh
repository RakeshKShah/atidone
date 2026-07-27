#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_updates_nonexistent_todo_returns_404"
TODO_ID="todo-nonexistent-${CASE_SUFFIX}"
USER_ID="user-123"
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

echo "STEP: Given — ensure target todo does not exist for authenticated user"
echo "PREREQ: deleting any residual todo ${TODO_ID}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM todos WHERE id = '${TODO_ID}';"

cat > "$REQUEST_BODY_FILE" <<JSON
{"completed":true}
JSON

echo "STEP: When — PATCH non-existent todo with authenticated session"
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

echo "STEP: Then — assert 404 and no row created"
[ "$PATCH_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${PATCH_CODE}"; exit 1; }
grep -F 'Todo not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT COUNT(*) FROM todos WHERE id = '${TODO_ID}';" > "$DB_RESULT"
DB_COUNT="$(cat "$DB_RESULT")"
[ "$DB_COUNT" = "0" ] || { echo "ASSERTION_FAILED: expected no database row for ${TODO_ID} but found ${DB_COUNT}"; exit 1; }

echo "STEP: Cleanup — ensure no todo row exists"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM todos WHERE id = '${TODO_ID}';"

echo "CODEVALID_TEST_ASSERTION_OK:user_updates_nonexistent_todo_returns_404"
