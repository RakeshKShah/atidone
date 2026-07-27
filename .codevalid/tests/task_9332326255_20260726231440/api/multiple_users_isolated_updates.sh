#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_users_isolated_updates"
USER1_ID="user-42-${CASE_SUFFIX}"
USER2_ID="user-88-${CASE_SUFFIX}"
TODO1_ID="todo-111-${CASE_SUFFIX}"
TODO2_ID="todo-222-${CASE_SUFFIX}"
SESSION1_ID="session-${TEST_ID}-u1-${CASE_SUFFIX}"
SESSION2_ID="session-${TEST_ID}-u2-${CASE_SUFFIX}"
BODY_TRUE_FILE="/tmp/${TEST_ID}_true_${CASE_SUFFIX}.json"
HEADERS1_FILE="/tmp/${TEST_ID}_headers1_${CASE_SUFFIX}.txt"
BODY1_FILE="/tmp/${TEST_ID}_body1_${CASE_SUFFIX}.txt"
HEADERS2_FILE="/tmp/${TEST_ID}_headers2_${CASE_SUFFIX}.txt"
BODY2_FILE="/tmp/${TEST_ID}_body2_${CASE_SUFFIX}.txt"
HEADERS3_FILE="/tmp/${TEST_ID}_headers3_${CASE_SUFFIX}.txt"
BODY3_FILE="/tmp/${TEST_ID}_body3_${CASE_SUFFIX}.txt"
HEADERS4_FILE="/tmp/${TEST_ID}_headers4_${CASE_SUFFIX}.txt"
BODY4_FILE="/tmp/${TEST_ID}_body4_${CASE_SUFFIX}.txt"
DB1_FILE="/tmp/${TEST_ID}_db1_${CASE_SUFFIX}.txt"
DB2_FILE="/tmp/${TEST_ID}_db2_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$BODY_TRUE_FILE" "$HEADERS1_FILE" "$BODY1_FILE" "$HEADERS2_FILE" "$BODY2_FILE" "$HEADERS3_FILE" "$BODY3_FILE" "$HEADERS4_FILE" "$BODY4_FILE" "$DB1_FILE" "$DB2_FILE"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
printf '{"completed":true}' > "$BODY_TRUE_FILE"

echo "STEP: Given — create two authenticated users with isolated sessions and todos"
echo "PREREQ: inserting both users, both sessions, and both todo rows"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
INSERT INTO users (id, email, password, name)
VALUES ('${USER1_ID}', '${USER1_ID}@example.com', 'password', 'User One ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO users (id, email, password, name)
VALUES ('${USER2_ID}', '${USER2_ID}@example.com', 'password', 'User Two ${CASE_SUFFIX}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO user_sessions (id, user_id, expires_at, created_at)
VALUES ('${SESSION1_ID}', '${USER1_ID}', NOW() + INTERVAL '1 day', NOW())
ON CONFLICT (id) DO NOTHING;
INSERT INTO user_sessions (id, user_id, expires_at, created_at)
VALUES ('${SESSION2_ID}', '${USER2_ID}', NOW() + INTERVAL '1 day', NOW())
ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('${TODO1_ID}', '${USER1_ID}', 'User one todo ${CASE_SUFFIX}', 0, NOW())
ON CONFLICT (id) DO NOTHING;
INSERT INTO todos (id, user_id, title, completed, created_at)
VALUES ('${TODO2_ID}', '${USER2_ID}', 'User two todo ${CASE_SUFFIX}', 0, NOW())
ON CONFLICT (id) DO NOTHING;
SQL

# When — perform the action under test
echo "STEP: When — user 1 updates own todo"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION1_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$BODY_TRUE_FILE")"
status1="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO1_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION1_ID}" \
  --data @"$BODY_TRUE_FILE" \
  -D "$HEADERS1_FILE" \
  -o "$BODY1_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS1_FILE"
echo "RESPONSE_BODY:"
cat "$BODY1_FILE"
echo
echo "RESPONSE_STATUS: $status1"

echo "STEP: When — user 2 updates own todo"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION2_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$BODY_TRUE_FILE")"
status2="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO2_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION2_ID}" \
  --data @"$BODY_TRUE_FILE" \
  -D "$HEADERS2_FILE" \
  -o "$BODY2_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS2_FILE"
echo "RESPONSE_BODY:"
cat "$BODY2_FILE"
echo
echo "RESPONSE_STATUS: $status2"

echo "STEP: When — user 1 attempts to update user 2's todo"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION1_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$BODY_TRUE_FILE")"
status3="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO2_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION1_ID}" \
  --data @"$BODY_TRUE_FILE" \
  -D "$HEADERS3_FILE" \
  -o "$BODY3_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS3_FILE"
echo "RESPONSE_BODY:"
cat "$BODY3_FILE"
echo
echo "RESPONSE_STATUS: $status3"

echo "STEP: When — user 2 attempts to update user 1's todo"
echo "REQUEST_HEADERS:"
echo "Cookie: nuxt-session=${SESSION2_ID}"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$BODY_TRUE_FILE")"
status4="$(curl -sS -X PATCH "$BASE_URL/api/todos/${TODO1_ID}" \
  -H 'Content-Type: application/json' \
  -H "Cookie: nuxt-session=${SESSION2_ID}" \
  --data @"$BODY_TRUE_FILE" \
  -D "$HEADERS4_FILE" \
  -o "$BODY4_FILE" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$HEADERS4_FILE"
echo "RESPONSE_BODY:"
cat "$BODY4_FILE"
echo
echo "RESPONSE_STATUS: $status4"

# Then — HTTP/body assertions
echo "STEP: Then — verify both own updates succeed and cross-user updates fail"
[ "$status1" = "200" ] || { echo "ASSERTION_FAILED: expected first own update HTTP 200 got ${status1}"; exit 1; }
[ "$status2" = "200" ] || { echo "ASSERTION_FAILED: expected second own update HTTP 200 got ${status2}"; exit 1; }
[ "$status3" = "404" ] || { echo "ASSERTION_FAILED: expected user1 cross-update HTTP 404 got ${status3}"; exit 1; }
[ "$status4" = "404" ] || { echo "ASSERTION_FAILED: expected user2 cross-update HTTP 404 got ${status4}"; exit 1; }
grep -F "${TODO1_ID}" "$BODY1_FILE" || { echo "ASSERTION_FAILED: expected user1 success response to contain ${TODO1_ID}"; exit 1; }
grep -F "${USER1_ID}" "$BODY1_FILE" || { echo "ASSERTION_FAILED: expected user1 success response to contain ${USER1_ID}"; exit 1; }
grep -F "${TODO2_ID}" "$BODY2_FILE" || { echo "ASSERTION_FAILED: expected user2 success response to contain ${TODO2_ID}"; exit 1; }
grep -F "${USER2_ID}" "$BODY2_FILE" || { echo "ASSERTION_FAILED: expected user2 success response to contain ${USER2_ID}"; exit 1; }
grep -F 'Todo not found' "$BODY3_FILE" || { echo "ASSERTION_FAILED: expected user1 cross-update body to contain Todo not found"; exit 1; }
grep -F 'Todo not found' "$BODY4_FILE" || { echo "ASSERTION_FAILED: expected user2 cross-update body to contain Todo not found"; exit 1; }
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -F ',' -c "SELECT id, user_id, completed FROM todos WHERE id = '${TODO1_ID}';" > "$DB1_FILE"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -t -A -F ',' -c "SELECT id, user_id, completed FROM todos WHERE id = '${TODO2_ID}';" > "$DB2_FILE"
grep -F "${TODO1_ID},${USER1_ID},1" "$DB1_FILE" || { echo "ASSERTION_FAILED: expected user1 todo to be completed and still owned by user1"; exit 1; }
grep -F "${TODO2_ID},${USER2_ID},1" "$DB2_FILE" || { echo "ASSERTION_FAILED: expected user2 todo to be completed and still owned by user2"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove both todos, both sessions, and both users"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE id = '${TODO1_ID}';
DELETE FROM todos WHERE id = '${TODO2_ID}';
DELETE FROM user_sessions WHERE id = '${SESSION1_ID}';
DELETE FROM user_sessions WHERE id = '${SESSION2_ID}';
DELETE FROM users WHERE id = '${USER1_ID}';
DELETE FROM users WHERE id = '${USER2_ID}';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_isolated_updates"
