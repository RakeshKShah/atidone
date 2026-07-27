#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_cannot_delete_another_users_todo"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
ALICE_ID="user-alice-${CASE_SUFFIX}"
BOB_ID="user-bob-${CASE_SUFFIX}"
TODO_ID="todo-bobs-123-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf 'session=%s\n' "$ALICE_ID" > "$COOKIE_JAR"
chmod 600 "$COOKIE_JAR"

echo "STEP: Given — seed Alice session and Bob-owned todo"
echo "PREREQ: inserting users, Alice session, and todo belonging only to Bob"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id) VALUES ('$ALICE_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO users (id) VALUES ('$BOB_ID') ON CONFLICT (id) DO NOTHING;
INSERT INTO sessions (id, user_id, expires_at)
VALUES ('sess-alice-${CASE_SUFFIX}', '$ALICE_ID', NOW() + INTERVAL '1 day')
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('$TODO_ID', '$BOB_ID', 'Bob private todo', 0, NOW())
ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, title = EXCLUDED.title, completed = EXCLUDED.completed;
SQL

# When — perform the action under test
REQUEST_BODY=''
echo "STEP: When — Alice attempts to delete Bob's todo"
echo "REQUEST_HEADERS:"
printf 'Cookie: session=%s\n' "$ALICE_ID"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
status_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status_code"

# Then — HTTP/body assertions
echo "STEP: Then — response is 404 and Bob's todo remains unchanged"
[ "$status_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${status_code}"; exit 1; }
grep -F 'Todo not found' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected Todo not found message in response body"; exit 1; }
remaining_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -c "SELECT COUNT(*) FROM todos WHERE id = '$TODO_ID' AND user_id = '$BOB_ID';")"
[ "$remaining_count" = "1" ] || { echo "ASSERTION_FAILED: expected Bob's todo $TODO_ID to remain, found count ${remaining_count}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove seeded todo, sessions, and users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '$TODO_ID';
DELETE FROM sessions WHERE id = 'sess-alice-${CASE_SUFFIX}';
DELETE FROM users WHERE id = '$ALICE_ID';
DELETE FROM users WHERE id = '$BOB_ID';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:user_cannot_delete_another_users_todo"
