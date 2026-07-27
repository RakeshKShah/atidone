#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="malformed_body_rejected"
USER_ID="user-42-${CASE_SUFFIX}"
TODO_ID="todo-555-${CASE_SUFFIX}"
SESSION_ID="session-${TEST_ID}-${CASE_SUFFIX}"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
PATCH_BODY_FILE="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.json"
DB_FILE="/tmp/${TEST_ID}_db_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$PATCH_BODY_FILE" "$DB_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf '{"status":"done"}' > "$PATCH_BODY_FILE"

echo "STEP: Given — create authenticated session and owned todo for malformed body validation"
echo "PREREQ: inserting user, session, and todo rows"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password, name)
VALUES ('${USER_ID}', '${USER_ID}@example.com', 'password', 'User ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO user_sessions (id, user_id, expires_at, created_at)
VALUES ('${SESSION_ID}', '${USER_ID}', NOW() + INTERVAL '1 day', NOW())
ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('${TODO_ID}', '${USER_ID}', 'Malformed body target ${CASE_SUFFIX}', 0, NOW())
ON CONFLICT (id) DO NOTHING;
SQL

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} with an invalid body schema"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$PATCH_BODY_FILE")"
status="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION_ID}" \
  --data @"$PATCH_BODY_FILE" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
echo "STEP: Then — verify body validation fails and todo remains unchanged"
[ "$status" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${status}"; exit 1; }
grep -Eiq 'completed|body|validation|required|invalid' "$BODY_FILE" || { echo "ASSERTION_FAILED: expected validation error mentioning completed/body schema"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -F ',' -c "SELECT id, user_id, completed FROM todos WHERE id = '${TODO_ID}';" > "$DB_FILE"
grep -F "${TODO_ID},${USER_ID},0" "$DB_FILE" || { echo "ASSERTION_FAILED: expected todo to remain unchanged after malformed body"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove todo, session, and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
DELETE FROM user_sessions WHERE id = '${SESSION_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:malformed_body_rejected"
