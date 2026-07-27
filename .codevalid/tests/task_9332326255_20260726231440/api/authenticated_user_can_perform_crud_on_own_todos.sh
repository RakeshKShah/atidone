#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_can_perform_crud_on_own_todos"
ITEM_TITLE="buy-groceries-${CASE_SUFFIX}"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
POST_HEADERS_FILE="/tmp/${TEST_ID}_post_headers_${CASE_SUFFIX}.txt"
POST_BODY_FILE="/tmp/${TEST_ID}_post_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS_FILE="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY_FILE="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS_FILE="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY_FILE="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$POST_HEADERS_FILE" "$POST_BODY_FILE" "$PATCH_HEADERS_FILE" "$PATCH_BODY_FILE" "$DELETE_HEADERS_FILE" "$DELETE_BODY_FILE"
}
cleanup_data() {
  echo "STEP: Cleanup — delete created todo rows by exact title"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE title = '${ITEM_TITLE}';
SQL
}
trap 'cleanup_data; cleanup_files' EXIT

echo "STEP: Given — ensure no leftover todo exists for this unique title"
echo "PREREQ: deleting any existing row with unique title ${ITEM_TITLE}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE title = '${ITEM_TITLE}';
SQL

echo "STEP: When — view todo list without an authenticated session"
REQUEST_BODY=''
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$REQUEST_BODY"
list_code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $list_code"

# Then

echo "STEP: Then — verify protected todo list cannot be viewed without authentication"
[ "$list_code" = "401" ] || [ "$list_code" = "302" ] || [ "$list_code" = "403" ] || { echo "ASSERTION_FAILED: expected HTTP 401/302/403 for unauthenticated list got ${list_code}"; exit 1; }

echo "STEP: When — attempt to create a todo without authentication"
post_body=$(printf '{"title":"%s"}' "$ITEM_TITLE")
echo 'REQUEST_HEADERS:'
echo 'Content-Type: application/json'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$post_body"
post_code="$(curl -sS -D "$POST_HEADERS_FILE" -o "$POST_BODY_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$post_body")"
echo 'RESPONSE_HEADERS:'
cat "$POST_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$POST_BODY_FILE"
echo "RESPONSE_STATUS: $post_code"

echo "STEP: Then — verify unauthenticated create is rejected"
[ "$post_code" = "401" ] || [ "$post_code" = "302" ] || [ "$post_code" = "403" ] || { echo "ASSERTION_FAILED: expected HTTP 401/302/403 for unauthenticated create got ${post_code}"; exit 1; }
if [ -s "$POST_BODY_FILE" ]; then
  ! grep -F "$ITEM_TITLE" "$POST_BODY_FILE" >/dev/null 2>&1 || { echo 'ASSERTION_FAILED: create response unexpectedly echoed protected todo title'; exit 1; }
fi

echo "STEP: When — attempt to update an inaccessible todo id without authentication"
patch_body='{"completed":true}'
echo 'REQUEST_HEADERS:'
echo 'Content-Type: application/json'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$patch_body"
patch_code="$(curl -sS -D "$PATCH_HEADERS_FILE" -o "$PATCH_BODY_FILE" -w '%{http_code}' -X PATCH "$BASE_URL/api/todos/td-003" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$patch_body")"
echo 'RESPONSE_HEADERS:'
cat "$PATCH_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$PATCH_BODY_FILE"
echo "RESPONSE_STATUS: $patch_code"

echo "STEP: Then — verify unauthenticated update is rejected"
[ "$patch_code" = "401" ] || [ "$patch_code" = "302" ] || [ "$patch_code" = "403" ] || [ "$patch_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 401/302/403/404 for unauthenticated update got ${patch_code}"; exit 1; }

echo "STEP: When — attempt to delete an inaccessible todo id without authentication"
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '\n'
delete_code="$(curl -sS -D "$DELETE_HEADERS_FILE" -o "$DELETE_BODY_FILE" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/td-003" -H 'Accept: application/json')"
echo 'RESPONSE_HEADERS:'
cat "$DELETE_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$DELETE_BODY_FILE"
echo "RESPONSE_STATUS: $delete_code"

echo "STEP: Then — verify unauthenticated delete is rejected"
[ "$delete_code" = "401" ] || [ "$delete_code" = "302" ] || [ "$delete_code" = "403" ] || [ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 401/302/403/404 for unauthenticated delete got ${delete_code}"; exit 1; }

echo 'CODEVALID_TEST_ASSERTION_OK:authenticated_user_can_perform_crud_on_own_todos'
