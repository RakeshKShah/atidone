#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_cannot_delete_todo"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
TODO_OWNER_ID="user-456-${CASE_SUFFIX}"
TODO_ID="todo-789-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state

echo "STEP: Given — seed a todo without providing any authenticated session"
echo "PREREQ: inserting todo owned by another user and leaving request unauthenticated"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('$TODO_OWNER_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('$TODO_ID', '$TODO_OWNER_ID', 'Protected todo', 0, NOW())
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, title = EXCLUDED.title, completed = EXCLUDED.completed;
SQL

# When — perform the action under test
REQUEST_BODY=''
echo "STEP: When — delete todo without session cookie"
echo "REQUEST_HEADERS:"
echo 'Cookie:'
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code="$(curl -sS -X DELETE \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status_code"

# Then — HTTP/body assertions
echo "STEP: Then — request is rejected and todo remains"
[ "$status_code" = "401" ] || { echo "ASSERTION_FAILED: expected HTTP 401 got ${status_code}"; exit 1; }
grep -F 'auth' "$BODY_FILE" >/dev/null || grep -F 'Unauthorized' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected unauthorized error message in response body"; exit 1; }
remaining_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '$TODO_ID' AND user_id = '$TODO_OWNER_ID';")"
[ "$remaining_count" = "1" ] || { echo "ASSERTION_FAILED: expected todo $TODO_ID to remain undeleted, found count ${remaining_count}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove seeded todo and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '$TODO_ID';
DELETE FROM users WHERE id = '$TODO_OWNER_ID';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_cannot_delete_todo"
