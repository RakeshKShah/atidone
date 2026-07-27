#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
USER_ID="user-123-${CASE_SUFFIX}"
OTHER_USER_ID="user-999-${CASE_SUFFIX}"
TODO_ID_1="todo-own-1-${CASE_SUFFIX}"
TODO_ID_2="todo-own-2-${CASE_SUFFIX}"
TODO_ID_3="todo-other-1-${CASE_SUFFIX}"
SESSION_COOKIE_VALUE="%7B%22user%22%3A%7B%22id%22%3A%22${USER_ID}%22%7D%7D"

RESPONSE_HEADERS="/tmp/authenticated_user_retrieves_own_todos_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/authenticated_user_retrieves_own_todos_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — seed own-user todos and another user's todo"
echo "PREREQ: inserting test-specific todo rows into the database"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES
  ('${TODO_ID_1}', '${USER_ID}', 'Buy milk ${CASE_SUFFIX}', 0, NOW()),
  ('${TODO_ID_2}', '${USER_ID}', 'Read book ${CASE_SUFFIX}', 0, NOW()),
  ('${TODO_ID_3}', '${OTHER_USER_ID}', 'Other user secret ${CASE_SUFFIX}', 0, NOW());
SQL

# When
echo "STEP: When — call GET /api/todos with an authenticated session cookie"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: nuxt-session=${SESSION_COOKIE_VALUE}"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -H "Cookie: nuxt-session=${SESSION_COOKIE_VALUE}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then
echo "STEP: Then — verify only the authenticated user's todos are returned"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
grep -F "$TODO_ID_1" "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include ${TODO_ID_1}"; exit 1; }
grep -F "$TODO_ID_2" "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include ${TODO_ID_2}"; exit 1; }
grep -F "Buy milk ${CASE_SUFFIX}" "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include Buy milk todo title"; exit 1; }
grep -F "Read book ${CASE_SUFFIX}" "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include Read book todo title"; exit 1; }
if grep -F "$TODO_ID_3" "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response unexpectedly included another user's todo id ${TODO_ID_3}"
  exit 1
fi
if grep -F "Other user secret ${CASE_SUFFIX}" "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response unexpectedly included another user's todo title"
  exit 1
fi

# Cleanup
echo "STEP: Cleanup — delete seeded todo rows"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID_1}';
DELETE FROM todos WHERE id = '${TODO_ID_2}';
DELETE FROM todos WHERE id = '${TODO_ID_3}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_retrieves_own_todos"
