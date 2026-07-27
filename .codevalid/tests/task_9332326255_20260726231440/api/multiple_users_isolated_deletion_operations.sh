#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_users_isolated_deletion_operations"
CAROL_COOKIE_JAR="/tmp/${TEST_ID}_carol_cookies_${CASE_SUFFIX}.txt"
DAVE_COOKIE_JAR="/tmp/${TEST_ID}_dave_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE_ONE="/tmp/${TEST_ID}_headers_one_${CASE_SUFFIX}.txt"
BODY_FILE_ONE="/tmp/${TEST_ID}_body_one_${CASE_SUFFIX}.txt"
HEADERS_FILE_TWO="/tmp/${TEST_ID}_headers_two_${CASE_SUFFIX}.txt"
BODY_FILE_TWO="/tmp/${TEST_ID}_body_two_${CASE_SUFFIX}.txt"
CAROL_ID="user-carol-${CASE_SUFFIX}"
DAVE_ID="user-dave-${CASE_SUFFIX}"
CAROL_TODO_ID="todo-carol-1-${CASE_SUFFIX}"
DAVE_TODO_ID="todo-dave-1-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$CAROL_COOKIE_JAR" "$DAVE_COOKIE_JAR" "$HEADERS_FILE_ONE" "$BODY_FILE_ONE" "$HEADERS_FILE_TWO" "$BODY_FILE_TWO"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf 'session=%s\n' "$CAROL_ID" > "$CAROL_COOKIE_JAR"
printf 'session=%s\n' "$DAVE_ID" > "$DAVE_COOKIE_JAR"
chmod 600 "$CAROL_COOKIE_JAR" "$DAVE_COOKIE_JAR"

echo "STEP: Given — seed two authenticated users and one todo for each"
echo "PREREQ: inserting Carol and Dave users, sessions, and isolated todos"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('$CAROL_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO users (id) VALUES ('$DAVE_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO sessions (id, user_id, expires_at)
VALUES ('sess-carol-${CASE_SUFFIX}', '$CAROL_ID', NOW() + INTERVAL '1 day')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;
INSERT INTO sessions (id, user_id, expires_at)
VALUES ('sess-dave-${CASE_SUFFIX}', '$DAVE_ID', NOW() + INTERVAL '1 day')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('$CAROL_TODO_ID', '$CAROL_ID', 'Carol private todo', 0, NOW())
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, title = EXCLUDED.title, completed = EXCLUDED.completed;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('$DAVE_TODO_ID', '$DAVE_ID', 'Dave private todo', 0, NOW())
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, title = EXCLUDED.title, completed = EXCLUDED.completed;
SQL

# When — perform the action under test
REQUEST_BODY=''
echo "STEP: When — Carol deletes her own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie: session=%s\n' "$CAROL_ID"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code_one="$(curl -sS -X DELETE \
  -b "$CAROL_COOKIE_JAR" \
  -D "$HEADERS_FILE_ONE" \
  -o "$BODY_FILE_ONE" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$CAROL_TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE_ONE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE_ONE"
echo "RESPONSE_STATUS: $status_code_one"

echo "STEP: When — Dave deletes his own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie: session=%s\n' "$DAVE_ID"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code_two="$(curl -sS -X DELETE \
  -b "$DAVE_COOKIE_JAR" \
  -D "$HEADERS_FILE_TWO" \
  -o "$BODY_FILE_TWO" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$DAVE_TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE_TWO"
echo "RESPONSE_BODY:"
cat "$BODY_FILE_TWO"
echo "RESPONSE_STATUS: $status_code_two"

# Then — HTTP/body assertions
echo "STEP: Then — both users delete only their own todos successfully"
[ "$status_code_one" = "200" ] || { echo "ASSERTION_FAILED: expected Carol delete HTTP 200 got ${status_code_one}"; exit 1; }
[ "$status_code_two" = "200" ] || { echo "ASSERTION_FAILED: expected Dave delete HTTP 200 got ${status_code_two}"; exit 1; }
grep -F '"id":"'"$CAROL_TODO_ID"'"' "$BODY_FILE_ONE" >/dev/null || { echo "ASSERTION_FAILED: expected Carol response body to contain todo id $CAROL_TODO_ID"; exit 1; }
grep -F '"userId":"'"$CAROL_ID"'"' "$BODY_FILE_ONE" >/dev/null || { echo "ASSERTION_FAILED: expected Carol response body to contain userId $CAROL_ID"; exit 1; }
grep -F '"id":"'"$DAVE_TODO_ID"'"' "$BODY_FILE_TWO" >/dev/null || { echo "ASSERTION_FAILED: expected Dave response body to contain todo id $DAVE_TODO_ID"; exit 1; }
grep -F '"userId":"'"$DAVE_ID"'"' "$BODY_FILE_TWO" >/dev/null || { echo "ASSERTION_FAILED: expected Dave response body to contain userId $DAVE_ID"; exit 1; }
carol_remaining="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '$CAROL_TODO_ID';")"
dave_remaining="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '$DAVE_TODO_ID';")"
[ "$carol_remaining" = "0" ] || { echo "ASSERTION_FAILED: expected Carol todo to be deleted, found count ${carol_remaining}"; exit 1; }
[ "$dave_remaining" = "0" ] || { echo "ASSERTION_FAILED: expected Dave todo to be deleted, found count ${dave_remaining}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove residual rows, sessions, and users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '$CAROL_TODO_ID';
DELETE FROM todos WHERE id = '$DAVE_TODO_ID';
DELETE FROM sessions WHERE id = 'sess-carol-${CASE_SUFFIX}';
DELETE FROM sessions WHERE id = 'sess-dave-${CASE_SUFFIX}';
DELETE FROM users WHERE id = '$CAROL_ID';
DELETE FROM users WHERE id = '$DAVE_ID';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_isolated_deletion_operations"
