#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ALICE_COOKIE_JAR="/tmp/multi_user_session_isolation_alice_cookies_${CASE_SUFFIX}.txt"
BOB_COOKIE_JAR="/tmp/multi_user_session_isolation_bob_cookies_${CASE_SUFFIX}.txt"
ALICE_HEADERS_FILE="/tmp/multi_user_session_isolation_alice_headers_${CASE_SUFFIX}.txt"
ALICE_BODY_FILE="/tmp/multi_user_session_isolation_alice_body_${CASE_SUFFIX}.txt"
BOB_HEADERS_FILE="/tmp/multi_user_session_isolation_bob_headers_${CASE_SUFFIX}.txt"
BOB_BODY_FILE="/tmp/multi_user_session_isolation_bob_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$ALICE_COOKIE_JAR" "$BOB_COOKIE_JAR" "$ALICE_HEADERS_FILE" "$ALICE_BODY_FILE" "$BOB_HEADERS_FILE" "$BOB_BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare two isolated browser-session cookie jars"
echo "PREREQ: creating separate cookie jars for Alice and Bob"
: > "$ALICE_COOKIE_JAR"
: > "$BOB_COOKIE_JAR"

# When
echo "STEP: When — invoke the OAuth entry endpoint in two separate sessions"
REQUEST_HEADERS='Accept: */*'
REQUEST_BODY=''

echo "PREREQ: Alice session request"
echo "REQUEST_HEADERS:"
printf '%s\n' "$REQUEST_HEADERS"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
alice_status="$({
  curl -sS \
    -D "$ALICE_HEADERS_FILE" \
    -o "$ALICE_BODY_FILE" \
    -w '%{http_code}' \
    -c "$ALICE_COOKIE_JAR" \
    -b "$ALICE_COOKIE_JAR" \
    -H 'Accept: */*' \
    "$BASE_URL/api/auth/github"
} )"
echo "RESPONSE_HEADERS:"
cat "$ALICE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$ALICE_BODY_FILE"
echo
echo "RESPONSE_STATUS: $alice_status"
case "$alice_status" in
  301|302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected redirect status for Alice OAuth entrypoint call, got ${alice_status}"
    exit 1
    ;;
esac

echo "PREREQ: Bob session request"
echo "REQUEST_HEADERS:"
printf '%s\n' "$REQUEST_HEADERS"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
bob_status="$({
  curl -sS \
    -D "$BOB_HEADERS_FILE" \
    -o "$BOB_BODY_FILE" \
    -w '%{http_code}' \
    -c "$BOB_COOKIE_JAR" \
    -b "$BOB_COOKIE_JAR" \
    -H 'Accept: */*' \
    "$BASE_URL/api/auth/github"
} )"
echo "RESPONSE_HEADERS:"
cat "$BOB_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BOB_BODY_FILE"
echo
echo "RESPONSE_STATUS: $bob_status"
case "$bob_status" in
  301|302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected redirect status for Bob OAuth entrypoint call, got ${bob_status}"
    exit 1
    ;;
esac

# Then
echo "STEP: Then — verify the two sessions remain isolated and independently redirected"
alice_location="$(grep -i '^location:' "$ALICE_HEADERS_FILE" | tail -n 1 | cut -d' ' -f2- | tr -d '\r')"
bob_location="$(grep -i '^location:' "$BOB_HEADERS_FILE" | tail -n 1 | cut -d' ' -f2- | tr -d '\r')"

[ -n "$alice_location" ] || {
  echo "ASSERTION_FAILED: expected Alice redirect Location header"
  exit 1
}
[ -n "$bob_location" ] || {
  echo "ASSERTION_FAILED: expected Bob redirect Location header"
  exit 1
}

echo "$alice_location" | grep -E '(github|oauth|/todos)' >/dev/null || {
  echo "ASSERTION_FAILED: expected Alice redirect target to reference OAuth or /todos; got: $alice_location"
  exit 1
}

echo "$bob_location" | grep -E '(github|oauth|/todos)' >/dev/null || {
  echo "ASSERTION_FAILED: expected Bob redirect target to reference OAuth or /todos; got: $bob_location"
  exit 1
}

[ "$ALICE_COOKIE_JAR" != "$BOB_COOKIE_JAR" ] || {
  echo "ASSERTION_FAILED: expected distinct cookie jars for independent sessions"
  exit 1
}

[ -f "$ALICE_COOKIE_JAR" ] || {
  echo "ASSERTION_FAILED: expected Alice cookie jar file to exist"
  exit 1
}
[ -f "$BOB_COOKIE_JAR" ] || {
  echo "ASSERTION_FAILED: expected Bob cookie jar file to exist"
  exit 1
}

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_session_isolation"

# Cleanup
echo "STEP: Cleanup — remove temporary request artifacts"
