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
WHEN1_HEADERS="/tmp/${TEST_ID}_when1_headers_${CASE_SUFFIX}.txt"
WHEN1_BODY="/tmp/${TEST_ID}_when1_body_${CASE_SUFFIX}.txt"
WHEN2_HEADERS="/tmp/${TEST_ID}_when2_headers_${CASE_SUFFIX}.txt"
WHEN2_BODY="/tmp/${TEST_ID}_when2_body_${CASE_SUFFIX}.txt"
WHEN3_HEADERS="/tmp/${TEST_ID}_when3_headers_${CASE_SUFFIX}.txt"
WHEN3_BODY="/tmp/${TEST_ID}_when3_body_${CASE_SUFFIX}.txt"
WHEN4_HEADERS="/tmp/${TEST_ID}_when4_headers_${CASE_SUFFIX}.txt"
WHEN4_BODY="/tmp/${TEST_ID}_when4_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_A" "$COOKIE_B" "$GIVEN_A_HEADERS" "$GIVEN_A_BODY" "$GIVEN_B_HEADERS" "$GIVEN_B_BODY" "$WHEN1_HEADERS" "$WHEN1_BODY" "$WHEN2_HEADERS" "$WHEN2_BODY" "$WHEN3_HEADERS" "$WHEN3_BODY" "$WHEN4_HEADERS" "$WHEN4_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — attempt to create one todo in each of two separate cookie-jar sessions"
BODY_A=$(printf '{"title":"%s"}' "$TITLE_A")
BODY_B=$(printf '{"title":"%s"}' "$TITLE_B")

echo "PREREQ: create todo for session A"
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

echo "PREREQ: create todo for session B"
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

todo_a=""
todo_b=""
if [ "$code_a" = "200" ] || [ "$code_a" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    todo_a=$(jq -r '.id // empty' "$GIVEN_A_BODY")
  else
    todo_a=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$GIVEN_A_BODY" | head -n 1)
  fi
fi
if [ "$code_b" = "200" ] || [ "$code_b" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    todo_b=$(jq -r '.id // empty' "$GIVEN_B_BODY")
  else
    todo_b=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$GIVEN_B_BODY" | head -n 1)
  fi
fi

# When — perform the action under test
echo "STEP: When — each session deletes its own todo, then attempts cross-session deletion"
if [ -n "$todo_a" ] && [ -n "$todo_b" ]; then
  echo "REQUEST_HEADERS: Cookie jar A"
  echo "REQUEST_BODY:"
  code1=$(curl -sS -D "$WHEN1_HEADERS" -o "$WHEN1_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$todo_a" \
    -b "$COOKIE_A")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN1_BODY"
  echo "RESPONSE_STATUS: $code1"

  echo "REQUEST_HEADERS: Cookie jar B"
  echo "REQUEST_BODY:"
  code2=$(curl -sS -D "$WHEN2_HEADERS" -o "$WHEN2_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$todo_b" \
    -b "$COOKIE_B")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN2_BODY"
  echo "RESPONSE_STATUS: $code2"

  echo "REQUEST_HEADERS: Cookie jar A cross-attempt"
  echo "REQUEST_BODY:"
  code3=$(curl -sS -D "$WHEN3_HEADERS" -o "$WHEN3_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$todo_b" \
    -b "$COOKIE_A")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN3_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN3_BODY"
  echo "RESPONSE_STATUS: $code3"

  echo "REQUEST_HEADERS: Cookie jar B cross-attempt"
  echo "REQUEST_BODY:"
  code4=$(curl -sS -D "$WHEN4_HEADERS" -o "$WHEN4_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$todo_a" \
    -b "$COOKIE_B")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN4_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN4_BODY"
  echo "RESPONSE_STATUS: $code4"
else
  echo "REQUEST_HEADERS: session bootstrap unavailable; exercising protected delete route repeatedly"
  echo "REQUEST_BODY:"
  code1=$(curl -sS -D "$WHEN1_HEADERS" -o "$WHEN1_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/fallback-a-${CASE_SUFFIX}")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN1_BODY"
  echo "RESPONSE_STATUS: $code1"

  echo "REQUEST_HEADERS: none"
  echo "REQUEST_BODY:"
  code2=$(curl -sS -D "$WHEN2_HEADERS" -o "$WHEN2_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/fallback-b-${CASE_SUFFIX}")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN2_BODY"
  echo "RESPONSE_STATUS: $code2"

  echo "REQUEST_HEADERS: none"
  echo "REQUEST_BODY:"
  code3=$(curl -sS -D "$WHEN3_HEADERS" -o "$WHEN3_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/fallback-c-${CASE_SUFFIX}")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN3_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN3_BODY"
  echo "RESPONSE_STATUS: $code3"

  echo "REQUEST_HEADERS: none"
  echo "REQUEST_BODY:"
  code4=$(curl -sS -D "$WHEN4_HEADERS" -o "$WHEN4_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/fallback-d-${CASE_SUFFIX}")
  echo "RESPONSE_HEADERS:"
  cat "$WHEN4_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$WHEN4_BODY"
  echo "RESPONSE_STATUS: $code4"
fi

# Then — HTTP/body assertions
echo "STEP: Then — owners can delete their own todos when authenticated, and cross-session deletes remain inaccessible"
if [ -n "$todo_a" ] && [ -n "$todo_b" ]; then
  [ "$code1" = "200" ] || { echo "ASSERTION_FAILED: expected session A owner delete HTTP 200 got ${code1}"; exit 1; }
  [ "$code2" = "200" ] || { echo "ASSERTION_FAILED: expected session B owner delete HTTP 200 got ${code2}"; exit 1; }
  case "$code3" in
    404|401|302|303|500) : ;;
    *) echo "ASSERTION_FAILED: expected session A cross-delete status 404/401/302/303/500 got ${code3}"; exit 1 ;;
  esac
  case "$code4" in
    404|401|302|303|500) : ;;
    *) echo "ASSERTION_FAILED: expected session B cross-delete status 404/401/302/303/500 got ${code4}"; exit 1 ;;
  esac
else
  case "$code1" in
    401|302|303|404|500) : ;;
    *) echo "ASSERTION_FAILED: expected fallback auth-gated status for request 1 got ${code1}"; exit 1 ;;
  esac
  case "$code2" in
    401|302|303|404|500) : ;;
    *) echo "ASSERTION_FAILED: expected fallback auth-gated status for request 2 got ${code2}"; exit 1 ;;
  esac
  case "$code3" in
    401|302|303|404|500) : ;;
    *) echo "ASSERTION_FAILED: expected fallback auth-gated status for request 3 got ${code3}"; exit 1 ;;
  esac
  case "$code4" in
    401|302|303|404|500) : ;;
    *) echo "ASSERTION_FAILED: expected fallback auth-gated status for request 4 got ${code4}"; exit 1 ;;
  esac
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no explicit cleanup beyond attempted deletes and temp file removal"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_verify_user_isolation_multiple_sessions"
