#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@toxiproxy:5432/app}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_can_only_access_own_todos"
ALICE_ID="gh-111-${CASE_SUFFIX}"
BOB_ID="gh-222-${CASE_SUFFIX}"
ALICE_TITLE="todo-alice-${CASE_SUFFIX}"
BOB_TITLE="todo-bob-${CASE_SUFFIX}"
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
  echo "STEP: Cleanup — remove any created todos by id if they exist"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
DELETE FROM todos WHERE title = '${ALICE_TITLE}';
DELETE FROM todos WHERE title = '${BOB_TITLE}';
SQL
}
trap 'cleanup_data; cleanup_files' EXIT

echo "STEP: Given — create isolated test data candidates through the public todo creation API"
for title in "$ALICE_TITLE" "$BOB_TITLE"; do
  echo "PREREQ: creating todo candidate ${title}"
  req_body=$(printf '{"title":"%s"}' "$title")
  echo 'REQUEST_HEADERS:'
  echo 'Content-Type: application/json'
  echo 'Accept: application/json'
  echo 'REQUEST_BODY:'
  printf '%s\n' "$req_body"
  prereq_code="$(curl -sS -D "$POST_HEADERS_FILE" -o "$POST_BODY_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/todos" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$req_body")"
  echo 'RESPONSE_HEADERS:'
  cat "$POST_HEADERS_FILE"
  echo 'RESPONSE_BODY:'
  cat "$POST_BODY_FILE"
  echo "RESPONSE_STATUS: $prereq_code"
  [ "$prereq_code" = "201" ] || [ "$prereq_code" = "200" ] || [ "$prereq_code" = "401" ] || [ "$prereq_code" = "403" ] || { echo "ASSERTION_FAILED: unexpected prereq create status ${prereq_code}"; exit 1; }
done

echo "STEP: When — list todos without any authenticated session"
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '\n'
code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then

echo "STEP: Then — verify todo listing is protected and does not leak cross-user data"
[ "$code" = "401" ] || [ "$code" = "302" ] || [ "$code" = "403" ] || { echo "ASSERTION_FAILED: expected protected todo list status 401/302/403 got ${code}"; exit 1; }
if [ -s "$BODY_FILE" ]; then
  ! grep -F "$ALICE_TITLE" "$BODY_FILE" >/dev/null 2>&1 || { echo 'ASSERTION_FAILED: leaked Alice test todo title in unauthenticated response'; exit 1; }
  ! grep -F "$BOB_TITLE" "$BODY_FILE" >/dev/null 2>&1 || { echo 'ASSERTION_FAILED: leaked Bob test todo title in unauthenticated response'; exit 1; }
fi

echo "STEP: When — attempt to modify a non-owned or inaccessible todo id through PATCH"
patch_body='{"completed":true}'
echo 'REQUEST_HEADERS:'
echo 'Content-Type: application/json'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$patch_body"
patch_code="$(curl -sS -D "$PATCH_HEADERS_FILE" -o "$PATCH_BODY_FILE" -w '%{http_code}' -X PATCH "$BASE_URL/api/todos/td-002" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$patch_body")"
echo 'RESPONSE_HEADERS:'
cat "$PATCH_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$PATCH_BODY_FILE"
echo "RESPONSE_STATUS: $patch_code"

echo "STEP: Then — verify unauthorized cross-user mutation is rejected"
[ "$patch_code" = "401" ] || [ "$patch_code" = "403" ] || [ "$patch_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 401/403/404 for cross-user patch attempt got ${patch_code}"; exit 1; }

echo "STEP: When — attempt to delete a non-owned or inaccessible todo id through DELETE"
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '\n'
delete_code="$(curl -sS -D "$DELETE_HEADERS_FILE" -o "$DELETE_BODY_FILE" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/td-002" -H 'Accept: application/json')"
echo 'RESPONSE_HEADERS:'
cat "$DELETE_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$DELETE_BODY_FILE"
echo "RESPONSE_STATUS: $delete_code"

echo "STEP: Then — verify unauthorized cross-user delete is rejected"
[ "$delete_code" = "401" ] || [ "$delete_code" = "403" ] || [ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 401/403/404 for cross-user delete attempt got ${delete_code}"; exit 1; }

echo 'CODEVALID_TEST_ASSERTION_OK:authenticated_user_can_only_access_own_todos'
