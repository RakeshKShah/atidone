#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
USER_A_ID="user-alice-${CASE_SUFFIX}"
USER_B_ID="user-bob-${CASE_SUFFIX}"
TODO_A_ID="todo-alice-1-${CASE_SUFFIX}"
TODO_B_ID="todo-bob-1-${CASE_SUFFIX}"
SESSION_COOKIE_A="%7B%22user%22%3A%7B%22id%22%3A%22${USER_A_ID}%22%7D%7D"
SESSION_COOKIE_B="%7B%22user%22%3A%7B%22id%22%3A%22${USER_B_ID}%22%7D%7D"

RESPONSE_A_HEADERS="/tmp/multi_user_isolation_todo_access_a_headers_${CASE_SUFFIX}.txt"
RESPONSE_A_BODY="/tmp/multi_user_isolation_todo_access_a_body_${CASE_SUFFIX}.txt"
RESPONSE_B_HEADERS="/tmp/multi_user_isolation_todo_access_b_headers_${CASE_SUFFIX}.txt"
RESPONSE_B_BODY="/tmp/multi_user_isolation_todo_access_b_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_A_HEADERS" "$RESPONSE_A_BODY" "$RESPONSE_B_HEADERS" "$RESPONSE_B_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — seed isolated todos for two separately authenticated users"
echo "PREREQ: inserting one todo for Alice and one todo for Bob"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES
  ('${TODO_A_ID}', '${USER_A_ID}', 'Alice task ${CASE_SUFFIX}', 0, NOW()),
  ('${TODO_B_ID}', '${USER_B_ID}', 'Bob task ${CASE_SUFFIX}', 0, NOW());
SQL

# When
echo "STEP: When — call GET /api/todos using Alice session"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: nuxt-session=${SESSION_COOKIE_A}"
echo "REQUEST_BODY: <empty>"
status_a="$(curl -sS -D "$RESPONSE_A_HEADERS" -o "$RESPONSE_A_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -H "Cookie: nuxt-session=${SESSION_COOKIE_A}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_A_BODY"
echo
echo "RESPONSE_STATUS: $status_a"

echo "STEP: When — call GET /api/todos using Bob session"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: nuxt-session=${SESSION_COOKIE_B}"
echo "REQUEST_BODY: <empty>"
status_b="$(curl -sS -D "$RESPONSE_B_HEADERS" -o "$RESPONSE_B_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -H "Cookie: nuxt-session=${SESSION_COOKIE_B}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_B_BODY"
echo
echo "RESPONSE_STATUS: $status_b"

# Then
echo "STEP: Then — verify each user can only see their own todo"
[ "$status_a" = "200" ] || { echo "ASSERTION_FAILED: expected Alice HTTP 200 got ${status_a}"; exit 1; }
[ "$status_b" = "200" ] || { echo "ASSERTION_FAILED: expected Bob HTTP 200 got ${status_b}"; exit 1; }
grep -F "$TODO_A_ID" "$RESPONSE_A_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response missing ${TODO_A_ID}"; exit 1; }
grep -F "Alice task ${CASE_SUFFIX}" "$RESPONSE_A_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response missing Alice task title"; exit 1; }
if grep -F "$TODO_B_ID" "$RESPONSE_A_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: Alice response unexpectedly included Bob todo id"
  exit 1
fi
if grep -F "Bob task ${CASE_SUFFIX}" "$RESPONSE_A_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: Alice response unexpectedly included Bob task title"
  exit 1
fi
grep -F "$TODO_B_ID" "$RESPONSE_B_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response missing ${TODO_B_ID}"; exit 1; }
grep -F "Bob task ${CASE_SUFFIX}" "$RESPONSE_B_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response missing Bob task title"; exit 1; }
if grep -F "$TODO_A_ID" "$RESPONSE_B_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: Bob response unexpectedly included Alice todo id"
  exit 1
fi
if grep -F "Alice task ${CASE_SUFFIX}" "$RESPONSE_B_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: Bob response unexpectedly included Alice task title"
  exit 1
fi

# Cleanup
echo "STEP: Cleanup — delete seeded rows for both users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_A_ID}';
DELETE FROM todos WHERE id = '${TODO_B_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_isolation_todo_access"
