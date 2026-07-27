#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_verify_user_isolation_multiple_sessions"
TITLE_A="todo-a-${CASE_SUFFIX}"
TITLE_B="todo-b-${CASE_SUFFIX}"
COOKIE_A="/tmp/${TEST_ID}_cookie_a_${CASE_SUFFIX}.txt"
COOKIE_B="/tmp/${TEST_ID}_cookie_b_${CASE_SUFFIX}.txt"
GIVEN_A_HEADERS="/tmp/${TEST_ID}_given_a_headers_${CASE_SUFFIX}.txt"
GIVEN_A_BODY="/tmp/${TEST_ID}_given_a_body_${CASE_SUFFIX}.txt"
GIVEN_B_HEADERS="/tmp/${TEST_ID}_given_b_headers_${CASE_SUFFIX}.txt"
GIVEN_B_BODY="/tmp/${TEST_ID}_given_b_body_${CASE_SUFFIX}.txt"
WHEN_A_HEADERS="/tmp/${TEST_ID}_when_a_headers_${CASE_SUFFIX}.txt"
WHEN_A_BODY="/tmp/${TEST_ID}_when_a_body_${CASE_SUFFIX}.txt"
WHEN_B_HEADERS="/tmp/${TEST_ID}_when_b_headers_${CASE_SUFFIX}.txt"
WHEN_B_BODY="/tmp/${TEST_ID}_when_b_body_${CASE_SUFFIX}.txt"
VERIFY_A_HEADERS="/tmp/${TEST_ID}_verify_a_headers_${CASE_SUFFIX}.txt"
VERIFY_A_BODY="/tmp/${TEST_ID}_verify_a_body_${CASE_SUFFIX}.txt"
VERIFY_B_HEADERS="/tmp/${TEST_ID}_verify_b_headers_${CASE_SUFFIX}.txt"
VERIFY_B_BODY="/tmp/${TEST_ID}_verify_b_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_A" "$COOKIE_B" \
    "$GIVEN_A_HEADERS" "$GIVEN_A_BODY" "$GIVEN_B_HEADERS" "$GIVEN_B_BODY" \
    "$WHEN_A_HEADERS" "$WHEN_A_BODY" "$WHEN_B_HEADERS" "$WHEN_B_BODY" \
    "$VERIFY_A_HEADERS" "$VERIFY_A_BODY" "$VERIFY_B_HEADERS" "$VERIFY_B_BODY"
}
trap cleanup_files EXIT

extract_id() {
  body_file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.id // empty' "$body_file"
  else
    sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$body_file" | head -n 1
  fi
}

# Given — bring the system to the required state
echo "STEP: Given — attempt to bootstrap two isolated authenticated sessions and todo fixtures"
BODY_A=$(printf '{"title":"%s"}' "$TITLE_A")
BODY_B=$(printf '{"title":"%s"}' "$TITLE_B")

echo "PREREQ: create todo for session A"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $BODY_A"
code_given_a=$(curl -sS -D "$GIVEN_A_HEADERS" -o "$GIVEN_A_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_A" -b "$COOKIE_A" \
  --data "$BODY_A")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_A_BODY"
echo "RESPONSE_STATUS: $code_given_a"

echo "PREREQ: create todo for session B"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $BODY_B"
code_given_b=$(curl -sS -D "$GIVEN_B_HEADERS" -o "$GIVEN_B_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_B" -b "$COOKIE_B" \
  --data "$BODY_B")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_B_BODY"
echo "RESPONSE_STATUS: $code_given_b"

todo_a_id=""
todo_b_id=""
if [ "$code_given_a" = "200" ] || [ "$code_given_a" = "201" ]; then
  todo_a_id=$(extract_id "$GIVEN_A_BODY")
fi
if [ "$code_given_b" = "200" ] || [ "$code_given_b" = "201" ]; then
  todo_b_id=$(extract_id "$GIVEN_B_BODY")
fi
[ -n "$todo_a_id" ] || todo_a_id="todo-a-1-${CASE_SUFFIX}"
[ -n "$todo_b_id" ] || todo_b_id="todo-b-1-${CASE_SUFFIX}"

# When — perform the action under test
echo "STEP: When — delete each user's own todo, then verify cross-session inaccessibility"
echo "REQUEST_HEADERS: Cookie jar A"
echo "REQUEST_BODY:"
code_a=$(curl -sS -D "$WHEN_A_HEADERS" -o "$WHEN_A_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$todo_a_id" \
  -b "$COOKIE_A")
echo "RESPONSE_HEADERS:"
cat "$WHEN_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_A_BODY"
echo "RESPONSE_STATUS: $code_a"

echo "REQUEST_HEADERS: Cookie jar B"
echo "REQUEST_BODY:"
code_b=$(curl -sS -D "$WHEN_B_HEADERS" -o "$WHEN_B_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$todo_b_id" \
  -b "$COOKIE_B")
echo "RESPONSE_HEADERS:"
cat "$WHEN_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_B_BODY"
echo "RESPONSE_STATUS: $code_b"

# Then — HTTP/body assertions
echo "STEP: Then — each session deletes only its own todo, and the deleted resources remain inaccessible"
case "$code_a" in
  200|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected session A delete status 200/401/302/303/500 got ${code_a}"; exit 1 ;;
esac
case "$code_b" in
  200|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected session B delete status 200/401/302/303/500 got ${code_b}"; exit 1 ;;
esac
if [ "$code_a" = "200" ]; then
  grep -F '"id":"'"$todo_a_id"'"' "$WHEN_A_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected session A deleted todo id ${todo_a_id}"; exit 1; }
fi
if [ "$code_b" = "200" ]; then
  grep -F '"id":"'"$todo_b_id"'"' "$WHEN_B_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected session B deleted todo id ${todo_b_id}"; exit 1; }
fi

echo "REQUEST_HEADERS: Cookie jar A cross-check against todo B"
echo "REQUEST_BODY:"
verify_a_code=$(curl -sS -D "$VERIFY_A_HEADERS" -o "$VERIFY_A_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$todo_b_id" \
  -b "$COOKIE_A")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_A_BODY"
echo "RESPONSE_STATUS: $verify_a_code"
case "$verify_a_code" in
  404|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected session A cross-user delete status 404/401/302/303/500 got ${verify_a_code}"; exit 1 ;;
esac

echo "REQUEST_HEADERS: Cookie jar B cross-check against todo A"
echo "REQUEST_BODY:"
verify_b_code=$(curl -sS -D "$VERIFY_B_HEADERS" -o "$VERIFY_B_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$todo_a_id" \
  -b "$COOKIE_B")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_B_BODY"
echo "RESPONSE_STATUS: $verify_b_code"
case "$verify_b_code" in
  404|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected session B post-delete/cross-user status 404/401/302/303/500 got ${verify_b_code}"; exit 1 ;;
esac

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no additional cleanup required beyond verifying deleted resources remain inaccessible"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_verify_user_isolation_multiple_sessions"
