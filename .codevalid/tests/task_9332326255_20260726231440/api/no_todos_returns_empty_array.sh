#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
USER_ID="bob-99-${CASE_SUFFIX}"
USER_EMAIL="bob-99-${CASE_SUFFIX}@example.com"
USER_PASSWORD="Password-${CASE_SUFFIX}!"
COOKIE_JAR="/tmp/no_todos_returns_empty_array_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS_FILE="/tmp/no_todos_returns_empty_array_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY_FILE="/tmp/no_todos_returns_empty_array_login_body_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/no_todos_returns_empty_array_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/no_todos_returns_empty_array_body_${CASE_SUFFIX}.txt"
SIGNIN_BODY_FILE="/tmp/no_todos_returns_empty_array_signin_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS_FILE" "$LOGIN_BODY_FILE" "$HEADERS_FILE" "$BODY_FILE" "$SIGNIN_BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — seed an authenticated user with no todos"
echo "PREREQ: remove any leftover rows for the case user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "PREREQ: insert the test user without todos"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password)
VALUES ('${USER_ID}', '${USER_EMAIL}', '${USER_PASSWORD}');
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
echo "STEP: When — request GET /api/todos for the user with no todos"
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
echo "STEP: Then — response is HTTP 200 with an empty array"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
trimmed_body="$(tr -d '[:space:]' < "$BODY_FILE")"
[ "$trimmed_body" = "[]" ] || { echo "ASSERTION_FAILED: expected empty array [] got ${trimmed_body}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove seeded user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:no_todos_returns_empty_array"
