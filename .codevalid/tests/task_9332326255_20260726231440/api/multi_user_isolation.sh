#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
ALICE_ID="alice-42-${CASE_SUFFIX}"
CHARLIE_ID="charlie-7-${CASE_SUFFIX}"
ALICE_TODO_ID="todo-a-${CASE_SUFFIX}"
CHARLIE_TODO_ID="todo-c-${CASE_SUFFIX}"
ALICE_EMAIL="alice-42-${CASE_SUFFIX}@example.com"
CHARLIE_EMAIL="charlie-7-${CASE_SUFFIX}@example.com"
ALICE_PASSWORD="Password-${CASE_SUFFIX}!"
CHARLIE_PASSWORD="Password-${CASE_SUFFIX}!"
ALICE_COOKIE_JAR="/tmp/multi_user_isolation_alice_cookies_${CASE_SUFFIX}.txt"
CHARLIE_COOKIE_JAR="/tmp/multi_user_isolation_charlie_cookies_${CASE_SUFFIX}.txt"
ALICE_LOGIN_HEADERS_FILE="/tmp/multi_user_isolation_alice_login_headers_${CASE_SUFFIX}.txt"
ALICE_LOGIN_BODY_FILE="/tmp/multi_user_isolation_alice_login_body_${CASE_SUFFIX}.txt"
CHARLIE_LOGIN_HEADERS_FILE="/tmp/multi_user_isolation_charlie_login_headers_${CASE_SUFFIX}.txt"
CHARLIE_LOGIN_BODY_FILE="/tmp/multi_user_isolation_charlie_login_body_${CASE_SUFFIX}.txt"
ALICE_HEADERS_FILE="/tmp/multi_user_isolation_alice_headers_${CASE_SUFFIX}.txt"
ALICE_BODY_FILE="/tmp/multi_user_isolation_alice_body_${CASE_SUFFIX}.txt"
CHARLIE_HEADERS_FILE="/tmp/multi_user_isolation_charlie_headers_${CASE_SUFFIX}.txt"
CHARLIE_BODY_FILE="/tmp/multi_user_isolation_charlie_body_${CASE_SUFFIX}.txt"
ALICE_SIGNIN_BODY_FILE="/tmp/multi_user_isolation_alice_signin_${CASE_SUFFIX}.json"
CHARLIE_SIGNIN_BODY_FILE="/tmp/multi_user_isolation_charlie_signin_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f \
    "$ALICE_COOKIE_JAR" "$CHARLIE_COOKIE_JAR" \
    "$ALICE_LOGIN_HEADERS_FILE" "$ALICE_LOGIN_BODY_FILE" \
    "$CHARLIE_LOGIN_HEADERS_FILE" "$CHARLIE_LOGIN_BODY_FILE" \
    "$ALICE_HEADERS_FILE" "$ALICE_BODY_FILE" \
    "$CHARLIE_HEADERS_FILE" "$CHARLIE_BODY_FILE" \
    "$ALICE_SIGNIN_BODY_FILE" "$CHARLIE_SIGNIN_BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — seed two users with isolated todos and establish separate sessions"
echo "PREREQ: clean any leftover rows for both users and todos"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${ALICE_TODO_ID}';
DELETE FROM todos WHERE id = '${CHARLIE_TODO_ID}';
DELETE FROM users WHERE id = '${ALICE_ID}';
DELETE FROM users WHERE id = '${CHARLIE_ID}';
SQL

echo "PREREQ: insert alice and charlie users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password)
VALUES
  ('${ALICE_ID}', '${ALICE_EMAIL}', '${ALICE_PASSWORD}'),
  ('${CHARLIE_ID}', '${CHARLIE_EMAIL}', '${CHARLIE_PASSWORD}');
SQL

echo "PREREQ: insert one todo per user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO todos (id, title, user_id, created_at, completed)
VALUES
  ('${ALICE_TODO_ID}', 'Alice task', '${ALICE_ID}', NOW(), 0),
  ('${CHARLIE_TODO_ID}', 'Charlie task', '${CHARLIE_ID}', NOW(), 0);
SQL

cat > "$ALICE_SIGNIN_BODY_FILE" <<JSON
{"email":"${ALICE_EMAIL}","password":"${ALICE_PASSWORD}"}
JSON
cat > "$CHARLIE_SIGNIN_BODY_FILE" <<JSON
{"email":"${CHARLIE_EMAIL}","password":"${CHARLIE_PASSWORD}"}
JSON

echo "PREREQ: sign in as alice"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "Accept: application/json"
echo "REQUEST_BODY:"
cat "$ALICE_SIGNIN_BODY_FILE"
alice_login_status="$(curl -sS -D "$ALICE_LOGIN_HEADERS_FILE" -o "$ALICE_LOGIN_BODY_FILE" -w '%{http_code}' \
  -c "$ALICE_COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -X POST \
  --data @"$ALICE_SIGNIN_BODY_FILE" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_LOGIN_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$ALICE_LOGIN_BODY_FILE"
echo "RESPONSE_STATUS: $alice_login_status"
if [ "$alice_login_status" != "200" ] && [ "$alice_login_status" != "201" ] && [ "$alice_login_status" != "204" ] && [ "$alice_login_status" != "302" ]; then
  echo "ASSERTION_FAILED: expected alice sign-in success got ${alice_login_status}"
  exit 1
fi

echo "PREREQ: sign in as charlie"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "Accept: application/json"
echo "REQUEST_BODY:"
cat "$CHARLIE_SIGNIN_BODY_FILE"
charlie_login_status="$(curl -sS -D "$CHARLIE_LOGIN_HEADERS_FILE" -o "$CHARLIE_LOGIN_BODY_FILE" -w '%{http_code}' \
  -c "$CHARLIE_COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -X POST \
  --data @"$CHARLIE_SIGNIN_BODY_FILE" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_LOGIN_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$CHARLIE_LOGIN_BODY_FILE"
echo "RESPONSE_STATUS: $charlie_login_status"
if [ "$charlie_login_status" != "200" ] && [ "$charlie_login_status" != "201" ] && [ "$charlie_login_status" != "204" ] && [ "$charlie_login_status" != "302" ]; then
  echo "ASSERTION_FAILED: expected charlie sign-in success got ${charlie_login_status}"
  exit 1
fi

# When
echo "STEP: When — both authenticated users request GET /api/todos in separate sessions"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: <alice cookie jar>"
echo "REQUEST_BODY:"
printf '\n'
alice_status="$(curl -sS -D "$ALICE_HEADERS_FILE" -o "$ALICE_BODY_FILE" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -b "$ALICE_COOKIE_JAR" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$ALICE_BODY_FILE"
echo "RESPONSE_STATUS: $alice_status"

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: <charlie cookie jar>"
echo "REQUEST_BODY:"
printf '\n'
charlie_status="$(curl -sS -D "$CHARLIE_HEADERS_FILE" -o "$CHARLIE_BODY_FILE" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -b "$CHARLIE_COOKIE_JAR" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$CHARLIE_BODY_FILE"
echo "RESPONSE_STATUS: $charlie_status"

# Then
echo "STEP: Then — each user sees only their own todo items"
[ "$alice_status" = "200" ] || { echo "ASSERTION_FAILED: expected alice HTTP 200 got ${alice_status}"; exit 1; }
[ "$charlie_status" = "200" ] || { echo "ASSERTION_FAILED: expected charlie HTTP 200 got ${charlie_status}"; exit 1; }
grep -F 'Alice task' "$ALICE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: alice response missing Alice task"; exit 1; }
grep -F "$ALICE_ID" "$ALICE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: alice response missing alice user id"; exit 1; }
! grep -F 'Charlie task' "$ALICE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: alice response leaked Charlie task"; exit 1; }
grep -F 'Charlie task' "$CHARLIE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: charlie response missing Charlie task"; exit 1; }
grep -F "$CHARLIE_ID" "$CHARLIE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: charlie response missing charlie user id"; exit 1; }
! grep -F 'Alice task' "$CHARLIE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: charlie response leaked Alice task"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove seeded todos and users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${ALICE_TODO_ID}';
DELETE FROM todos WHERE id = '${CHARLIE_TODO_ID}';
DELETE FROM users WHERE id = '${ALICE_ID}';
DELETE FROM users WHERE id = '${CHARLIE_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_isolation"
