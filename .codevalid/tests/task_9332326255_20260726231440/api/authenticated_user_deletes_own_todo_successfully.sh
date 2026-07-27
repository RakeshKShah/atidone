#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_deletes_own_todo_successfully"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
SESSION_USER_ID="user-123-${CASE_SUFFIX}"
TODO_ID="todo-456-${CASE_SUFFIX}"
TODO_TITLE="Buy groceries"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf 'session=%s\n' "$SESSION_USER_ID" > "$COOKIE_JAR"
chmod 600 "$COOKIE_JAR"

echo "STEP: Given — seed authenticated user session and owned todo"
echo "PREREQ: inserting user session and todo owned by deleting user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('$SESSION_USER_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO sessions (id, user_id, expires_at)
VALUES ('sess-${CASE_SUFFIX}', '$SESSION_USER_ID', NOW() + INTERVAL '1 day')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('$TODO_ID', '$SESSION_USER_ID', '$TODO_TITLE', 0, NOW())
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, title = EXCLUDED.title, completed = EXCLUDED.completed;
SQL

# When — perform the action under test
REQUEST_BODY=''
echo "STEP: When — delete authenticated user's own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie: session=%s\n' "$SESSION_USER_ID"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
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
echo "STEP: Then — response returns deleted todo and row is gone"
[ "$status_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status_code}"; exit 1; }
grep -F '"id":"'"$TODO_ID"'"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain deleted todo id $TODO_ID"; exit 1; }
grep -F '"userId":"'"$SESSION_USER_ID"'"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain userId $SESSION_USER_ID"; exit 1; }
grep -F '"title":"'"$TODO_TITLE"'"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain title $TODO_TITLE"; exit 1; }
remaining_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '$TODO_ID';")"
[ "$remaining_count" = "0" ] || { echo "ASSERTION_FAILED: expected todo $TODO_ID to be deleted from database, found count ${remaining_count}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove seeded session and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '$TODO_ID';
DELETE FROM sessions WHERE id = 'sess-${CASE_SUFFIX}';
DELETE FROM users WHERE id = '$SESSION_USER_ID';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_deletes_own_todo_successfully"
