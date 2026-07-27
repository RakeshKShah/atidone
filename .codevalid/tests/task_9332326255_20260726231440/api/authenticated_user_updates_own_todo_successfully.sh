#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_updates_own_todo_successfully"
USER_ID="user-42-${CASE_SUFFIX}"
TODO_ID="todo-111-${CASE_SUFFIX}"
SESSION_ID="session-${TEST_ID}-${CASE_SUFFIX}"
COOKIE_FILE="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
PATCH_BODY_FILE="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.json"
DB_FILE="/tmp/${TEST_ID}_db_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_FILE" "$HEADERS_FILE" "$BODY_FILE" "$PATCH_BODY_FILE" "$DB_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf '{"completed":true}' > "$PATCH_BODY_FILE"

echo "STEP: Given — create an authenticated user session and owned todo"
echo "PREREQ: inserting user, session, and todo rows for ${USER_ID}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password, name)
VALUES ('${USER_ID}', '${USER_ID}@example.com', 'password', 'User 42 ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO user_sessions (id, user_id, expires_at, created_at)
VALUES ('${SESSION_ID}', '${USER_ID}', NOW() + INTERVAL '1 day', NOW())
ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('${TODO_ID}', '${USER_ID}', 'Owned todo ${CASE_SUFFIX}', 0, NOW())
ON CONFLICT (id) DO NOTHING;
SQL
printf 'Cookie: nuxt-session=%s\n' "$SESSION_ID" > "$COOKIE_FILE"

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} as the owning authenticated user"
echo "REQUEST_HEADERS:"
cat "$COOKIE_FILE"
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
echo "STEP: Then — verify the todo is updated and persisted"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
grep -F "${TODO_ID}" "$BODY_FILE" || { echo "ASSERTION_FAILED: expected response body to contain todo id ${TODO_ID}"; exit 1; }
grep -F "${USER_ID}" "$BODY_FILE" || { echo "ASSERTION_FAILED: expected response body to contain user id ${USER_ID}"; exit 1; }
grep -E '"completed"[[:space:]]*:[[:space:]]*(1|true)' "$BODY_FILE" || { echo "ASSERTION_FAILED: expected response body to contain completed=true/1"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -F ',' -c "SELECT id, user_id, completed FROM todos WHERE id = '${TODO_ID}';" > "$DB_FILE"
grep -F "${TODO_ID},${USER_ID},1" "$DB_FILE" || { echo "ASSERTION_FAILED: expected database row ${TODO_ID},${USER_ID},1"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove created todo, session, and user"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO_ID}';
DELETE FROM user_sessions WHERE id = '${SESSION_ID}';
DELETE FROM users WHERE id = '${USER_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_updates_own_todo_successfully"
