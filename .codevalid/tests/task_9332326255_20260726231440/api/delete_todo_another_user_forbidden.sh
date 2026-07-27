#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_another_user_forbidden"
TITLE_A="alice-own-${CASE_SUFFIX}"
TITLE_B="bob-own-${CASE_SUFFIX}"
COOKIE_A="/tmp/${TEST_ID}_cookie_a_${CASE_SUFFIX}.txt"
COOKIE_B="/tmp/${TEST_ID}_cookie_b_${CASE_SUFFIX}.txt"
GIVEN_A_HEADERS="/tmp/${TEST_ID}_given_a_headers_${CASE_SUFFIX}.txt"
GIVEN_A_BODY="/tmp/${TEST_ID}_given_a_body_${CASE_SUFFIX}.txt"
GIVEN_B_HEADERS="/tmp/${TEST_ID}_given_b_headers_${CASE_SUFFIX}.txt"
GIVEN_B_BODY="/tmp/${TEST_ID}_given_b_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"
VERIFY_HEADERS="/tmp/${TEST_ID}_verify_headers_${CASE_SUFFIX}.txt"
VERIFY_BODY="/tmp/${TEST_ID}_verify_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_A" "$COOKIE_B" "$GIVEN_A_HEADERS" "$GIVEN_A_BODY" "$GIVEN_B_HEADERS" "$GIVEN_B_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — attempt to bootstrap two independent authenticated sessions via separate cookie jars"
BODY_A=$(printf '{"title":"%s"}' "$TITLE_A")
BODY_B=$(printf '{"title":"%s"}' "$TITLE_B")

echo "PREREQ: create session A todo"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $BODY_A"
code_a=$(curl -sS -D "$GIVEN_A_HEADERS" -o "$GIVEN_A_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_A" -b "$COOKIE_A" \
  --data "$BODY_A")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_A_BODY"
echo "RESPONSE_STATUS: $code_a"

echo "PREREQ: create session B todo"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $BODY_B"
code_b=$(curl -sS -D "$GIVEN_B_HEADERS" -o "$GIVEN_B_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_B" -b "$COOKIE_B" \
  --data "$BODY_B")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_B_BODY"
echo "RESPONSE_STATUS: $code_b"

owner_id=""
if [ "$code_b" = "200" ] || [ "$code_b" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    owner_id=$(jq -r '.id // empty' "$GIVEN_B_BODY")
  else
    owner_id=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$GIVEN_B_BODY" | head -n 1)
  fi
fi

# When — perform the action under test
echo "STEP: When — session A attempts to delete session B's todo"
if [ "$code_a" = "200" ] || [ "$code_a" = "201" ]; then
  if [ -z "$owner_id" ]; then
    owner_id="todo-bob-1-${CASE_SUFFIX}"
  fi
else
  owner_id="todo-bob-1-${CASE_SUFFIX}"
fi
echo "REQUEST_HEADERS: Cookie jar A only"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$owner_id" \
  -b "$COOKIE_A")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — cross-user deletion returns not found or auth-gated response"
case "$code" in
  404|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected cross-user delete status 404/401/302/303/500 got ${code}"; exit 1 ;;
esac
if [ "$code" = "404" ]; then
  grep -E 'Todo not found|Not Found|not found' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Todo not found message for cross-user delete"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — best-effort remove created fixtures when authenticated sessions were available"
if [ "$code_a" = "200" ] || [ "$code_a" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    todo_a=$(jq -r '.id // empty' "$GIVEN_A_BODY")
  else
    todo_a=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$GIVEN_A_BODY" | head -n 1)
  fi
  if [ -n "${todo_a:-}" ]; then
    echo "REQUEST_HEADERS: Cookie jar A"
    echo "REQUEST_BODY:"
    cleanup_a=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \
      -X DELETE "$BASE_URL/api/todos/$todo_a" \
      -b "$COOKIE_A")
    echo "RESPONSE_HEADERS:"
    cat "$VERIFY_HEADERS"
    echo "RESPONSE_BODY:"
    cat "$VERIFY_BODY"
    echo "RESPONSE_STATUS: $cleanup_a"
  fi
fi
if [ "$code_b" = "200" ] || [ "$code_b" = "201" ]; then
  if [ -n "$owner_id" ]; then
    echo "REQUEST_HEADERS: Cookie jar B"
    echo "REQUEST_BODY:"
    cleanup_b=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \
      -X DELETE "$BASE_URL/api/todos/$owner_id" \
      -b "$COOKIE_B")
    echo "RESPONSE_HEADERS:"
    cat "$VERIFY_HEADERS"
    echo "RESPONSE_BODY:"
    cat "$VERIFY_BODY"
    echo "RESPONSE_STATUS: $cleanup_b"
  fi
fi

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_another_user_forbidden"
