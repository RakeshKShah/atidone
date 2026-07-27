#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_with_invalid_id_format_rejected"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
USER_ID="user-valid-${CASE_SUFFIX}"
INVALID_ID='%20'

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf 'session=%s\n' "$USER_ID" > "$COOKIE_JAR"
chmod 600 "$COOKIE_JAR"

echo "STEP: Given — seed authenticated user session"
echo "PREREQ: inserting user and active session for validation failure scenario"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('$USER_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO sessions (id, user_id, expires_at)
VALUES ('sess-${CASE_SUFFIX}', '$USER_ID', NOW() + INTERVAL '1 day')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;
SQL
before_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos;")"

# When — perform the action under test
REQUEST_BODY=''
echo "STEP: When — send delete request with invalid id format"
echo "REQUEST_HEADERS:"
printf 'Cookie: session=%s\n' "$USER_ID"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$INVALID_ID")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status_code"

# Then — HTTP/body assertions
echo "STEP: Then — validation error is returned and no delete occurs"
[ "$status_code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${status_code}"; exit 1; }
grep -F 'id' "$BODY_FILE" >/dev/null || grep -F 'validation' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected validation details in response body"; exit 1; }
after_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos;")"
[ "$after_count" = "$before_count" ] || { echo "ASSERTION_FAILED: expected todo row count to remain unchanged, before=${before_count} after=${after_count}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove seeded session and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM sessions WHERE id = 'sess-${CASE_SUFFIX}';
DELETE FROM users WHERE id = '$USER_ID';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:delete_with_invalid_id_format_rejected"
