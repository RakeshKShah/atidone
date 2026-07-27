#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_verify_isolation_multiple_users"
ALICE_ID="user-alice-${CASE_SUFFIX}"
BOB_ID="user-bob-${CASE_SUFFIX}"
ALICE_TODO_ID="todo-alice-1-${CASE_SUFFIX}"
BOB_TODO_ID="todo-bob-1-${CASE_SUFFIX}"
ALICE_COOKIE_JAR="/tmp/${TEST_ID}_alice_cookies_${CASE_SUFFIX}.txt"
BOB_COOKIE_JAR="/tmp/${TEST_ID}_bob_cookies_${CASE_SUFFIX}.txt"
ALICE_LOGIN_HEADERS="/tmp/${TEST_ID}_alice_login_headers_${CASE_SUFFIX}.txt"
ALICE_LOGIN_BODY="/tmp/${TEST_ID}_alice_login_body_${CASE_SUFFIX}.txt"
BOB_LOGIN_HEADERS="/tmp/${TEST_ID}_bob_login_headers_${CASE_SUFFIX}.txt"
BOB_LOGIN_BODY="/tmp/${TEST_ID}_bob_login_body_${CASE_SUFFIX}.txt"
WHEN1_HEADERS="/tmp/${TEST_ID}_when1_headers_${CASE_SUFFIX}.txt"
WHEN1_BODY="/tmp/${TEST_ID}_when1_body_${CASE_SUFFIX}.txt"
WHEN2_HEADERS="/tmp/${TEST_ID}_when2_headers_${CASE_SUFFIX}.txt"
WHEN2_BODY="/tmp/${TEST_ID}_when2_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$ALICE_COOKIE_JAR" "$BOB_COOKIE_JAR" \
    "$ALICE_LOGIN_HEADERS" "$ALICE_LOGIN_BODY" "$BOB_LOGIN_HEADERS" "$BOB_LOGIN_BODY" \
    "$WHEN1_HEADERS" "$WHEN1_BODY" "$WHEN2_HEADERS" "$WHEN2_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — create two users, two sessions, and isolated todos"
echo "PREREQ: inserting users and todos directly in database"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('${ALICE_ID}') ON CONFLICT (id) DO NOTHING;
INSERT INTO users (id) VALUES ('${BOB_ID}') ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, title, completed, user_id)
VALUES ('${ALICE_TODO_ID}', 'Alice todo', FALSE, '${ALICE_ID}')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, completed = EXCLUDED.completed, user_id = EXCLUDED.user_id;
INSERT INTO todos (id, title, completed, user_id)
VALUES ('${BOB_TODO_ID}', 'Bob todo', FALSE, '${BOB_ID}')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, completed = EXCLUDED.completed, user_id = EXCLUDED.user_id;
SQL

echo "PREREQ: creating session for Alice"
ALICE_LOGIN_JSON=$(printf '{"userId":"%s"}' "$ALICE_ID")
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $ALICE_LOGIN_JSON"
alice_login_code=$(curl -sS -D "$ALICE_LOGIN_HEADERS" -o "$ALICE_LOGIN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/test/login" \
  -H 'Content-Type: application/json' \
  -c "$ALICE_COOKIE_JAR" \
  --data "$ALICE_LOGIN_JSON")
echo "RESPONSE_HEADERS:"
cat "$ALICE_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_LOGIN_BODY"
echo "RESPONSE_STATUS: $alice_login_code"
[ "$alice_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${alice_login_code}"; exit 1; }

echo "PREREQ: creating session for Bob"
BOB_LOGIN_JSON=$(printf '{"userId":"%s"}' "$BOB_ID")
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $BOB_LOGIN_JSON"
bob_login_code=$(curl -sS -D "$BOB_LOGIN_HEADERS" -o "$BOB_LOGIN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/test/login" \
  -H 'Content-Type: application/json' \
  -c "$BOB_COOKIE_JAR" \
  --data "$BOB_LOGIN_JSON")
echo "RESPONSE_HEADERS:"
cat "$BOB_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_LOGIN_BODY"
echo "RESPONSE_STATUS: $bob_login_code"
[ "$bob_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${bob_login_code}"; exit 1; }

# When — perform the action under test
echo "STEP: When — Alice tries to delete Bob's todo, then Bob deletes his own todo"
echo "REQUEST_HEADERS: Alice authenticated cookie jar"
echo "REQUEST_BODY:"
code1=$(curl -sS -D "$WHEN1_HEADERS" -o "$WHEN1_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$BOB_TODO_ID" \
  -b "$ALICE_COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN1_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN1_BODY"
echo "RESPONSE_STATUS: $code1"

echo "REQUEST_HEADERS: Bob authenticated cookie jar"
echo "REQUEST_BODY:"
code2=$(curl -sS -D "$WHEN2_HEADERS" -o "$WHEN2_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$BOB_TODO_ID" \
  -b "$BOB_COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN2_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN2_BODY"
echo "RESPONSE_STATUS: $code2"

# Then — HTTP/body assertions
echo "STEP: Then — first request is blocked, second succeeds, Alice todo remains"
[ "$code1" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${code1}"; exit 1; }
grep -F 'Todo not found' "$WHEN1_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected first response to contain Todo not found"; exit 1; }
[ "$code2" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code2}"; exit 1; }
grep -F '"id":"'"$BOB_TODO_ID"'"' "$WHEN2_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected second response to contain deleted Bob todo id"; exit 1; }
grep -F '"userId":"'"$BOB_ID"'"' "$WHEN2_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected second response to contain Bob user id"; exit 1; }
alice_remaining=$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '${ALICE_TODO_ID}' AND user_id = '${ALICE_ID}';")
[ "$alice_remaining" = "1" ] || { echo "ASSERTION_FAILED: expected Alice todo ${ALICE_TODO_ID} to remain"; exit 1; }
bob_remaining=$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '${BOB_TODO_ID}';")
[ "$bob_remaining" = "0" ] || { echo "ASSERTION_FAILED: expected Bob todo ${BOB_TODO_ID} to be deleted"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove fixture rows"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${ALICE_TODO_ID}';
DELETE FROM todos WHERE id = '${BOB_TODO_ID}';
DELETE FROM users WHERE id = '${ALICE_ID}';
DELETE FROM users WHERE id = '${BOB_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_verify_isolation_multiple_users"
