#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="update_nonexistent_todo_returns_404"
USER_ID="user-42-${CASE_SUFFIX}"
TODO_ID="todo-404-${CASE_SUFFIX}"
SESSION_ID="session-${TEST_ID}-${CASE_SUFFIX}"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
PATCH_BODY_FILE="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.json"
DB_COUNT_FILE="/tmp/${TEST_ID}_db_count_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$PATCH_BODY_FILE" "$DB_COUNT_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf '{"completed":true}' > "$PATCH_BODY_FILE"

echo "STEP: Given — create authenticated session and ensure target todo does not exist"
echo "PREREQ: inserting user/session and deleting any conflicting todo id"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password, name)
VALUES ('${USER_ID}', '${USER_ID}@example.com', 'password', 'User ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO user_sessions (id, user_id, expires_at, created_at)
VALUES ('${SESSION_ID}', '${USER_ID}', NOW() + INTERVAL '1 day', NOW())
ON CONFLICT (id) DO NOTHING;
DELETE FROM todos WHERE id = '${TODO_ID}';
SQL

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} for a non-existent todo"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$PATCH_BODY_FILE")"
status="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION_ID}" \
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
echo "STEP: Then — verify 404 is returned and no row was created"
[ "$status" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${status}"; exit 1; }
grep -F 'Todo not found' "$BODY_FILE" || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '${TODO_ID}';" > "$DB_COUNT_FILE"
[ "$(tr -d '[:space:]' < "$DB_COUNT_FILE")" = "0" ] || { echo "ASSERTION_FAILED: expected no todo row with id ${TODO_ID}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove session and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM user_sessions WHERE id = '${SESSION_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:update_nonexistent_todo_returns_404"
