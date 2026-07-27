#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
USER_ID="alice-42-${CASE_SUFFIX}"
ITEM_ID_A="todo-a-${CASE_SUFFIX}"
ITEM_ID_B="todo-b-${CASE_SUFFIX}"
USER_EMAIL="alice-42-${CASE_SUFFIX}@example.com"
USER_PASSWORD="Password-${CASE_SUFFIX}!"
COOKIE_JAR="/tmp/authenticated_user_lists_own_todos_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS_FILE="/tmp/authenticated_user_lists_own_todos_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY_FILE="/tmp/authenticated_user_lists_own_todos_login_body_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/authenticated_user_lists_own_todos_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/authenticated_user_lists_own_todos_body_${CASE_SUFFIX}.txt"
SIGNIN_BODY_FILE="/tmp/authenticated_user_lists_own_todos_signin_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS_FILE" "$LOGIN_BODY_FILE" "$HEADERS_FILE" "$BODY_FILE" "$SIGNIN_BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — seed one user with two personal todos and authenticate"
echo "PREREQ: clean any leftover rows for deterministic setup"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${ITEM_ID_A}';
DELETE FROM todos WHERE id = '${ITEM_ID_B}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "PREREQ: insert the test user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password)
VALUES ('${USER_ID}', '${USER_EMAIL}', '${USER_PASSWORD}');
SQL

echo "PREREQ: insert two todos owned by the test user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO todos (id, title, user_id, created_at, completed)
VALUES
  ('${ITEM_ID_A}', 'Buy groceries', '${USER_ID}', NOW(), 0),
  ('${ITEM_ID_B}', 'Read book', '${USER_ID}', NOW(), 0);
SQL

cat > "$SIGNIN_BODY_FILE" <<JSON
{"email":"${USER_EMAIL}","password":"${USER_PASSWORD}"}
JSON

echo "PREREQ: sign in to establish a session"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "Accept: application/json"
echo "REQUEST_BODY:"
cat "$SIGNIN_BODY_FILE"
login_status="$(curl -sS -D "$LOGIN_HEADERS_FILE" -o "$LOGIN_BODY_FILE" -w '%{http_code}' \
  -c "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -X POST \
  --data @"$SIGNIN_BODY_FILE" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY_FILE"
echo "RESPONSE_STATUS: $login_status"
if [ "$login_status" != "200" ] && [ "$login_status" != "201" ] && [ "$login_status" != "204" ] && [ "$login_status" != "302" ]; then
  echo "ASSERTION_FAILED: expected sign-in success status got ${login_status}"
  exit 1
fi

# When
echo "STEP: When — request GET /api/todos with authenticated session"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: <from cookie jar>"
echo "REQUEST_BODY:"
printf '\n'
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -b "$COOKIE_JAR" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

# Then
echo "STEP: Then — response contains exactly the authenticated user's todos"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
grep -F 'Buy groceries' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: missing first todo title"; exit 1; }
grep -F 'Read book' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: missing second todo title"; exit 1; }
grep -F "$USER_ID" "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: missing authenticated user id in response"; exit 1; }
! grep -F 'Charlie task' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: leaked another user's todo"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove seeded todos and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${ITEM_ID_A}';
DELETE FROM todos WHERE id = '${ITEM_ID_B}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_lists_own_todos"
