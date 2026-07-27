#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
TOXIPROXY_API_URL="${TOXIPROXY_API_URL:-http://toxiproxy:8474}"
CASE_SUFFIX="$(date +%s)-$$"
USER_ID="alice-42-${CASE_SUFFIX}"
USER_EMAIL="alice-42-${CASE_SUFFIX}@example.com"
USER_PASSWORD="Password-${CASE_SUFFIX}!"
TOXIC_NAME="timeout_${CASE_SUFFIX}"
COOKIE_JAR="/tmp/database_query_failure_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS_FILE="/tmp/database_query_failure_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY_FILE="/tmp/database_query_failure_login_body_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/database_query_failure_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/database_query_failure_body_${CASE_SUFFIX}.txt"
TOXIC_HEADERS_FILE="/tmp/database_query_failure_toxic_headers_${CASE_SUFFIX}.txt"
TOXIC_BODY_FILE="/tmp/database_query_failure_toxic_body_${CASE_SUFFIX}.txt"
TOXIC_DELETE_HEADERS_FILE="/tmp/database_query_failure_toxic_delete_headers_${CASE_SUFFIX}.txt"
TOXIC_DELETE_BODY_FILE="/tmp/database_query_failure_toxic_delete_body_${CASE_SUFFIX}.txt"
SIGNIN_BODY_FILE="/tmp/database_query_failure_signin_${CASE_SUFFIX}.json"
TOXIC_REQUEST_FILE="/tmp/database_query_failure_toxic_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f \
    "$COOKIE_JAR" "$LOGIN_HEADERS_FILE" "$LOGIN_BODY_FILE" \
    "$HEADERS_FILE" "$BODY_FILE" \
    "$TOXIC_HEADERS_FILE" "$TOXIC_BODY_FILE" \
    "$TOXIC_DELETE_HEADERS_FILE" "$TOXIC_DELETE_BODY_FILE" \
    "$SIGNIN_BODY_FILE" "$TOXIC_REQUEST_FILE"
}
cleanup_toxic() {
  curl -sS -D "$TOXIC_DELETE_HEADERS_FILE" -o "$TOXIC_DELETE_BODY_FILE" -w '%{http_code}' \
    -X DELETE "$TOXIPROXY_API_URL/proxies/postgres/toxics/$TOXIC_NAME" >/dev/null 2>&1 || true
}
trap 'cleanup_toxic; cleanup_files' EXIT

# Given
echo "STEP: Given — seed an authenticated user and break postgres through toxiproxy"
echo "PREREQ: remove any leftover rows for deterministic setup"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "PREREQ: insert the test user"
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

cat > "$TOXIC_REQUEST_FILE" <<JSON
{"name":"${TOXIC_NAME}","type":"timeout","stream":"downstream","attributes":{"timeout":0}}
JSON

echo "PREREQ: create a toxiproxy timeout toxic for postgres"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$TOXIC_REQUEST_FILE"
toxic_status="$(curl -sS -D "$TOXIC_HEADERS_FILE" -o "$TOXIC_BODY_FILE" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -X POST \
  --data @"$TOXIC_REQUEST_FILE" \
  "$TOXIPROXY_API_URL/proxies/postgres/toxics")"
echo "RESPONSE_HEADERS:"
cat "$TOXIC_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$TOXIC_BODY_FILE"
echo "RESPONSE_STATUS: $toxic_status"
[ "$toxic_status" = "200" ] || { echo "ASSERTION_FAILED: expected toxic create HTTP 200 got ${toxic_status}"; exit 1; }

# When
echo "STEP: When — request GET /api/todos while the database is unavailable"
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
echo "STEP: Then — a generic server error is returned without leaking internals"
[ "$status" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 500 got ${status}"; exit 1; }
! grep -Fi 'stack' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: response leaked stack trace details"; exit 1; }
! grep -Fi 'drizzle' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: response leaked ORM internals"; exit 1; }
! grep -Fi 'postgres' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: response leaked database internals"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove toxic and seeded user"
delete_status="$(curl -sS -D "$TOXIC_DELETE_HEADERS_FILE" -o "$TOXIC_DELETE_BODY_FILE" -w '%{http_code}' \
  -X DELETE "$TOXIPROXY_API_URL/proxies/postgres/toxics/$TOXIC_NAME")"
if [ "$delete_status" != "200" ] && [ "$delete_status" != "204" ] && [ "$delete_status" != "404" ]; then
  echo "ASSERTION_FAILED: expected toxic delete HTTP 200, 204, or 404 got ${delete_status}"
  exit 1
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE user_id = '${USER_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:database_query_failure"
