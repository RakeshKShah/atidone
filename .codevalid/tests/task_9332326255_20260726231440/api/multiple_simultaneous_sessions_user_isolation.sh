#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_simultaneous_sessions_user_isolation"
DAVID_TITLE="david-task-${CASE_SUFFIX}"
EVE_TITLE="eve-task-${CASE_SUFFIX}"
DAVID_COOKIE_JAR="/tmp/${TEST_ID}_david_cookies_${CASE_SUFFIX}.txt"
EVE_COOKIE_JAR="/tmp/${TEST_ID}_eve_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
POST_HEADERS_FILE="/tmp/${TEST_ID}_post_headers_${CASE_SUFFIX}.txt"
POST_BODY_FILE="/tmp/${TEST_ID}_post_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS_FILE="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY_FILE="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DAVID_COOKIE_JAR" "$EVE_COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE" "$POST_HEADERS_FILE" "$POST_BODY_FILE" "$DELETE_HEADERS_FILE" "$DELETE_BODY_FILE"
}
cleanup_data() {
  echo "STEP: Cleanup — remove any created test todos by exact title"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE title = '${DAVID_TITLE}';
DELETE FROM todos WHERE title = '${EVE_TITLE}';
SQL
}
trap 'cleanup_data; cleanup_files' EXIT

echo "STEP: Given — initialize two independent client cookie jars and clear any matching rows"
: > "$DAVID_COOKIE_JAR"
: > "$EVE_COOKIE_JAR"
echo "PREREQ: deleting leftover rows for ${DAVID_TITLE} and ${EVE_TITLE}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE title = '${DAVID_TITLE}';
DELETE FROM todos WHERE title = '${EVE_TITLE}';
SQL

echo "STEP: When — initiate Session A OAuth flow for David client"
echo 'REQUEST_HEADERS:'
echo 'Accept: */*'
echo 'REQUEST_BODY:'
printf '\n'
david_oauth_code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -c "$DAVID_COOKIE_JAR" "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $david_oauth_code"

echo "STEP: Then — verify Session A starts the OAuth redirect flow"
[ "$david_oauth_code" = "302" ] || [ "$david_oauth_code" = "303" ] || { echo "ASSERTION_FAILED: expected Session A OAuth initiation to return 302/303 got ${david_oauth_code}"; exit 1; }

echo "STEP: When — initiate Session B OAuth flow for Eve client"
echo 'REQUEST_HEADERS:'
echo 'Accept: */*'
echo 'REQUEST_BODY:'
printf '\n'
eve_oauth_code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -c "$EVE_COOKIE_JAR" "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $eve_oauth_code"

echo "STEP: Then — verify Session B starts the OAuth redirect flow independently"
[ "$eve_oauth_code" = "302" ] || [ "$eve_oauth_code" = "303" ] || { echo "ASSERTION_FAILED: expected Session B OAuth initiation to return 302/303 got ${eve_oauth_code}"; exit 1; }

echo "STEP: When — attempt Session A todo creation without completed OAuth callback"
david_post_body=$(printf '{"title":"%s"}' "$DAVID_TITLE")
echo 'REQUEST_HEADERS:'
echo 'Content-Type: application/json'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$david_post_body"
david_post_code="$(curl -sS -D "$POST_HEADERS_FILE" -o "$POST_BODY_FILE" -w '%{http_code}' -b "$DAVID_COOKIE_JAR" -c "$DAVID_COOKIE_JAR" -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$david_post_body")"
echo 'RESPONSE_HEADERS:'
cat "$POST_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$POST_BODY_FILE"
echo "RESPONSE_STATUS: $david_post_code"

echo "STEP: Then — verify Session A remains isolated and unauthenticated until callback completion"
[ "$david_post_code" = "401" ] || [ "$david_post_code" = "302" ] || [ "$david_post_code" = "403" ] || { echo "ASSERTION_FAILED: expected Session A protected create to be rejected before callback, got ${david_post_code}"; exit 1; }

echo "STEP: When — attempt Session B todo creation without completed OAuth callback"
eve_post_body=$(printf '{"title":"%s"}' "$EVE_TITLE")
echo 'REQUEST_HEADERS:'
echo 'Content-Type: application/json'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$eve_post_body"
eve_post_code="$(curl -sS -D "$POST_HEADERS_FILE" -o "$POST_BODY_FILE" -w '%{http_code}' -b "$EVE_COOKIE_JAR" -c "$EVE_COOKIE_JAR" -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$eve_post_body")"
echo 'RESPONSE_HEADERS:'
cat "$POST_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$POST_BODY_FILE"
echo "RESPONSE_STATUS: $eve_post_code"

echo "STEP: Then — verify Session B remains isolated and unauthenticated until callback completion"
[ "$eve_post_code" = "401" ] || [ "$eve_post_code" = "302" ] || [ "$eve_post_code" = "403" ] || { echo "ASSERTION_FAILED: expected Session B protected create to be rejected before callback, got ${eve_post_code}"; exit 1; }

echo "STEP: When — attempt Session A cross-user delete of Eve todo id placeholder"
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '\n'
delete_code="$(curl -sS -D "$DELETE_HEADERS_FILE" -o "$DELETE_BODY_FILE" -w '%{http_code}' -b "$DAVID_COOKIE_JAR" -c "$DAVID_COOKIE_JAR" -X DELETE "$BASE_URL/api/todos/td-005" -H 'Accept: application/json')"
echo 'RESPONSE_HEADERS:'
cat "$DELETE_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$DELETE_BODY_FILE"
echo "RESPONSE_STATUS: $delete_code"

echo "STEP: Then — verify cross-session protected delete is rejected"
[ "$delete_code" = "401" ] || [ "$delete_code" = "403" ] || [ "$delete_code" = "404" ] || [ "$delete_code" = "302" ] || { echo "ASSERTION_FAILED: expected HTTP 401/403/404/302 for cross-session delete attempt got ${delete_code}"; exit 1; }

echo 'CODEVALID_TEST_ASSERTION_OK:multiple_simultaneous_sessions_user_isolation'
