#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_unauthenticated_blocked"
OWNER_ID="user-owner-${CASE_SUFFIX}"
TODO_ID="todo-789-${CASE_SUFFIX}"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — create todo without authenticating request"
echo "PREREQ: inserting owner and todo rows directly in database"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('${OWNER_ID}') ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, title, completed, user_id)
VALUES ('${TODO_ID}', 'Unauth protected todo', FALSE, '${OWNER_ID}')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, completed = EXCLUDED.completed, user_id = EXCLUDED.user_id;
SQL

# When — perform the action under test
echo "STEP: When — delete todo without authentication"
echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$TODO_ID")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — request is rejected and todo remains"
[ "$code" = "401" ] || { echo "ASSERTION_FAILED: expected HTTP 401 got ${code}"; exit 1; }
remaining_count=$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '${TODO_ID}' AND user_id = '${OWNER_ID}';")
[ "$remaining_count" = "1" ] || { echo "ASSERTION_FAILED: expected todo ${TODO_ID} to remain in database"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove fixture rows"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
DELETE FROM users WHERE id = '${OWNER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_unauthenticated_blocked"
