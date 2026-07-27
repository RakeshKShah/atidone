#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_response_structure"
USER_ID="user-123-${CASE_SUFFIX}"
TODO_ID="todo-struct-${CASE_SUFFIX}"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/${TEST_ID}_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/${TEST_ID}_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — create authenticated user and completed todo fixture"
echo "PREREQ: inserting user and todo rows directly in database"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('${USER_ID}') ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, title, completed, user_id)
VALUES ('${TODO_ID}', 'Test Todo', TRUE, '${USER_ID}')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, completed = EXCLUDED.completed, user_id = EXCLUDED.user_id;
SQL

echo "PREREQ: creating authenticated session cookie"
LOGIN_BODY=$(printf '{"userId":"%s"}' "$USER_ID")
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $LOGIN_BODY"
login_code=$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/test/login" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" \
  --data "$LOGIN_BODY")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $login_code"
[ "$login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${login_code}"; exit 1; }

# When — perform the action under test
echo "STEP: When — delete todo and capture full response object"
echo "REQUEST_HEADERS: Cookie jar from authenticated login"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$TODO_ID" \
  -b "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — deleted todo object contains expected fields"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
grep -F '"id":"'"$TODO_ID"'"' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected id field ${TODO_ID}"; exit 1; }
grep -F '"userId":"'"$USER_ID"'"' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected userId field ${USER_ID}"; exit 1; }
grep -F '"title":"Test Todo"' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected title field Test Todo"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e 'has("id") and has("userId") and has("title") and has("completed")' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response object to contain id,userId,title,completed"; exit 1; }
  jq -e '.completed == true or .completed == 1' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected completed to be true/1"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove residual fixtures"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_response_structure"
