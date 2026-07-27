#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_patch_rejected"
TODO_ID="todo-111-${CASE_SUFFIX}"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
PATCH_BODY_FILE="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.json"
DB_BEFORE_FILE="/tmp/${TEST_ID}_db_before_${CASE_SUFFIX}.txt"
DB_AFTER_FILE="/tmp/${TEST_ID}_db_after_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$PATCH_BODY_FILE" "$DB_BEFORE_FILE" "$DB_AFTER_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf '{"completed":true}' > "$PATCH_BODY_FILE"

echo "STEP: Given — create an existing todo without any authenticated session"
echo "PREREQ: inserting todo row ${TODO_ID} owned by a separate user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password, name)
VALUES ('owner-${CASE_SUFFIX}', 'owner-${CASE_SUFFIX}@example.com', 'password', 'Owner ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('${TODO_ID}', 'owner-${CASE_SUFFIX}', 'Unauthenticated patch target ${CASE_SUFFIX}', 0, NOW())
ON CONFLICT (id) DO NOTHING;
SQL
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COALESCE(CAST(completed AS TEXT), '') FROM todos WHERE id = '${TODO_ID}';" > "$DB_BEFORE_FILE"

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} without authentication"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $(cat "$PATCH_BODY_FILE")"
status="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO_ID}" \
  -H 'Content-Type: application/json' \
  --data @"$PATCH_BODY_FILE" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
echo "STEP: Then — verify auth is required and data is unchanged"
[ "$status" = "401" ] || { echo "ASSERTION_FAILED: expected HTTP 401 got ${status}"; exit 1; }
grep -Eiq 'auth|unauth|session|login|sign.?in|credential' "$BODY_FILE" || { echo "ASSERTION_FAILED: expected authentication error message in response body"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COALESCE(CAST(completed AS TEXT), '') FROM todos WHERE id = '${TODO_ID}';" > "$DB_AFTER_FILE"
[ "$(tr -d '[:space:]' < "$DB_BEFORE_FILE")" = "$(tr -d '[:space:]' < "$DB_AFTER_FILE")" ] || { echo "ASSERTION_FAILED: expected todo completed flag to remain unchanged"; exit 1; }
[ "$(tr -d '[:space:]' < "$DB_AFTER_FILE")" = "0" ] || { echo "ASSERTION_FAILED: expected todo completed flag to remain 0"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove inserted todo and owner user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
DELETE FROM users WHERE id = 'owner-${CASE_SUFFIX}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_patch_rejected"
