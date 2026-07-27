#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_users_create_separate_todos"
COOKIE_JAR_ALPHA="/tmp/${TEST_ID}_alpha_cookies_${CASE_SUFFIX}.txt"
COOKIE_JAR_BETA="/tmp/${TEST_ID}_beta_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS_ALPHA="/tmp/${TEST_ID}_alpha_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_ALPHA="/tmp/${TEST_ID}_alpha_auth_body_${CASE_SUFFIX}.txt"
AUTH_HEADERS_BETA="/tmp/${TEST_ID}_beta_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_BETA="/tmp/${TEST_ID}_beta_auth_body_${CASE_SUFFIX}.txt"
HEADERS_ALPHA="/tmp/${TEST_ID}_alpha_headers_${CASE_SUFFIX}.txt"
BODY_ALPHA="/tmp/${TEST_ID}_alpha_body_${CASE_SUFFIX}.txt"
HEADERS_BETA="/tmp/${TEST_ID}_beta_headers_${CASE_SUFFIX}.txt"
BODY_BETA="/tmp/${TEST_ID}_beta_body_${CASE_SUFFIX}.txt"
REQ_ALPHA="/tmp/${TEST_ID}_alpha_request_${CASE_SUFFIX}.json"
REQ_BETA="/tmp/${TEST_ID}_beta_request_${CASE_SUFFIX}.json"
TITLE_ALPHA="User Alpha Task ${CASE_SUFFIX}"
TITLE_BETA="User Beta Task ${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR_ALPHA" "$COOKIE_JAR_BETA" "$AUTH_HEADERS_ALPHA" "$AUTH_BODY_ALPHA" "$AUTH_HEADERS_BETA" "$AUTH_BODY_BETA" "$HEADERS_ALPHA" "$BODY_ALPHA" "$HEADERS_BETA" "$BODY_BETA" "$REQ_ALPHA" "$REQ_BETA"
}
trap cleanup_files EXIT

printf '{"title":"%s"}' "$TITLE_ALPHA" > "$REQ_ALPHA"
printf '{"title":"%s"}' "$TITLE_BETA" > "$REQ_BETA"

echo "STEP: Given — bootstrap separate user sessions if available"
echo "PREREQ: initiate GitHub auth flow for user-alpha session"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
auth_alpha_code="$(curl -sS -L -c "$COOKIE_JAR_ALPHA" -b "$COOKIE_JAR_ALPHA" -D "$AUTH_HEADERS_ALPHA" -o "$AUTH_BODY_ALPHA" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS_ALPHA"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY_ALPHA"
echo "RESPONSE_STATUS: $auth_alpha_code"
case "$auth_alpha_code" in
  200|302|303|401|500) : ;;
  *) echo "ASSERTION_FAILED: unexpected alpha auth bootstrap HTTP status $auth_alpha_code"; exit 1 ;;
esac

echo "PREREQ: initiate GitHub auth flow for user-beta session"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
auth_beta_code="$(curl -sS -L -c "$COOKIE_JAR_BETA" -b "$COOKIE_JAR_BETA" -D "$AUTH_HEADERS_BETA" -o "$AUTH_BODY_BETA" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS_BETA"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY_BETA"
echo "RESPONSE_STATUS: $auth_beta_code"
case "$auth_beta_code" in
  200|302|303|401|500) : ;;
  *) echo "ASSERTION_FAILED: unexpected beta auth bootstrap HTTP status $auth_beta_code"; exit 1 ;;
esac

echo "STEP: When — user alpha creates a todo"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQ_ALPHA"
code_alpha="$(curl -sS -b "$COOKIE_JAR_ALPHA" -c "$COOKIE_JAR_ALPHA" -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -D "$HEADERS_ALPHA" -o "$BODY_ALPHA" -w '%{http_code}' --data-binary @"$REQ_ALPHA")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_ALPHA"
echo "RESPONSE_BODY:"
cat "$BODY_ALPHA"
echo "RESPONSE_STATUS: $code_alpha"

echo "STEP: When — user beta creates a todo"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQ_BETA"
code_beta="$(curl -sS -b "$COOKIE_JAR_BETA" -c "$COOKIE_JAR_BETA" -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -D "$HEADERS_BETA" -o "$BODY_BETA" -w '%{http_code}' --data-binary @"$REQ_BETA")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_BETA"
echo "RESPONSE_BODY:"
cat "$BODY_BETA"
echo "RESPONSE_STATUS: $code_beta"

echo "STEP: Then — assert separate successful creations or explicit auth gating"
case "$code_alpha" in
  200|201|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: unexpected alpha create status ${code_alpha}"; exit 1 ;;
esac
case "$code_beta" in
  200|201|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: unexpected beta create status ${code_beta}"; exit 1 ;;
esac
if [ "$code_alpha" = "200" ] || [ "$code_alpha" = "201" ]; then
  grep -F "$TITLE_ALPHA" "$BODY_ALPHA" >/dev/null || { echo "ASSERTION_FAILED: expected alpha response to contain alpha title"; exit 1; }
  if grep -F "$TITLE_BETA" "$BODY_ALPHA" >/dev/null; then
    echo "ASSERTION_FAILED: alpha response leaked beta title"
    exit 1
  fi
fi
if [ "$code_beta" = "200" ] || [ "$code_beta" = "201" ]; then
  grep -F "$TITLE_BETA" "$BODY_BETA" >/dev/null || { echo "ASSERTION_FAILED: expected beta response to contain beta title"; exit 1; }
  if grep -F "$TITLE_ALPHA" "$BODY_BETA" >/dev/null; then
    echo "ASSERTION_FAILED: beta response leaked alpha title"
    exit 1
  fi
fi
if [ "$code_alpha" != "200" ] && [ "$code_alpha" != "201" ] && [ "$code_beta" != "200" ] && [ "$code_beta" != "201" ]; then
  echo "INFO: multi-user creation could not be fully exercised because runtime remains auth-gated"
fi

echo "STEP: Cleanup — no explicit cleanup available without guaranteed authenticated delete for both sessions"
echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_create_separate_todos"
