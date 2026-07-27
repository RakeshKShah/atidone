#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRIMARY_EMAIL="codevalid-many-${CASE_SUFFIX}@example.com"
PRIMARY_PASSWORD="CodevalidMany-${CASE_SUFFIX}!"
OTHER_EMAIL="codevalid-many-other-${CASE_SUFFIX}@example.com"
OTHER_PASSWORD="CodevalidManyOther-${CASE_SUFFIX}!"
PRIMARY_COOKIE_JAR="/tmp/multiple_todos_retrieval_ordered_primary_cookie_${CASE_SUFFIX}.txt"
OTHER_COOKIE_JAR="/tmp/multiple_todos_retrieval_ordered_other_cookie_${CASE_SUFFIX}.txt"
PRIMARY_SIGNUP_HEADERS="/tmp/multiple_todos_retrieval_ordered_primary_signup_headers_${CASE_SUFFIX}.txt"
PRIMARY_SIGNUP_BODY="/tmp/multiple_todos_retrieval_ordered_primary_signup_body_${CASE_SUFFIX}.txt"
PRIMARY_LOGIN_HEADERS="/tmp/multiple_todos_retrieval_ordered_primary_login_headers_${CASE_SUFFIX}.txt"
PRIMARY_LOGIN_BODY="/tmp/multiple_todos_retrieval_ordered_primary_login_body_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_HEADERS="/tmp/multiple_todos_retrieval_ordered_other_signup_headers_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_BODY="/tmp/multiple_todos_retrieval_ordered_other_signup_body_${CASE_SUFFIX}.txt"
OTHER_LOGIN_HEADERS="/tmp/multiple_todos_retrieval_ordered_other_login_headers_${CASE_SUFFIX}.txt"
OTHER_LOGIN_BODY="/tmp/multiple_todos_retrieval_ordered_other_login_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/multiple_todos_retrieval_ordered_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/multiple_todos_retrieval_ordered_list_body_${CASE_SUFFIX}.txt"
OTHER_LIST_HEADERS="/tmp/multiple_todos_retrieval_ordered_other_list_headers_${CASE_SUFFIX}.txt"
OTHER_LIST_BODY="/tmp/multiple_todos_retrieval_ordered_other_list_body_${CASE_SUFFIX}.txt"

PRIMARY_IDS=""
OTHER_TODO_ID=""

cleanup_files() {
  rm -f "$PRIMARY_COOKIE_JAR" "$OTHER_COOKIE_JAR" \
    "$PRIMARY_SIGNUP_HEADERS" "$PRIMARY_SIGNUP_BODY" "$PRIMARY_LOGIN_HEADERS" "$PRIMARY_LOGIN_BODY" \
    "$OTHER_SIGNUP_HEADERS" "$OTHER_SIGNUP_BODY" "$OTHER_LOGIN_HEADERS" "$OTHER_LOGIN_BODY" \
    "$LIST_HEADERS" "$LIST_BODY" "$OTHER_LIST_HEADERS" "$OTHER_LIST_BODY" \
    /tmp/multiple_todos_retrieval_ordered_create_*_${CASE_SUFFIX}.txt \
    /tmp/multiple_todos_retrieval_ordered_delete_*_${CASE_SUFFIX}.txt \
    /tmp/multiple_todos_retrieval_ordered_other_create_*_${CASE_SUFFIX}.txt \
    /tmp/multiple_todos_retrieval_ordered_other_delete_*_${CASE_SUFFIX}.txt
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — create an authenticated user with many todos and another authenticated user with a separate todo"
echo "PREREQ: sign up the primary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${PRIMARY_EMAIL}\",\"password\":\"***\"}"
primary_signup_code="$(curl -sS -c "$PRIMARY_COOKIE_JAR" -D "$PRIMARY_SIGNUP_HEADERS" -o "$PRIMARY_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${PRIMARY_EMAIL}\",\"password\":\"${PRIMARY_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$PRIMARY_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$PRIMARY_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $primary_signup_code"
[ "$primary_signup_code" = "200" ] || [ "$primary_signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected primary sign-up HTTP 200 or 201 got ${primary_signup_code}"; exit 1; }

echo "PREREQ: sign in the primary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${PRIMARY_EMAIL}\",\"password\":\"***\"}"
primary_login_code="$(curl -sS -b "$PRIMARY_COOKIE_JAR" -c "$PRIMARY_COOKIE_JAR" -D "$PRIMARY_LOGIN_HEADERS" -o "$PRIMARY_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${PRIMARY_EMAIL}\",\"password\":\"${PRIMARY_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$PRIMARY_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$PRIMARY_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $primary_login_code"
[ "$primary_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected primary sign-in HTTP 200 got ${primary_login_code}"; exit 1; }

echo "PREREQ: sign up the secondary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_signup_code="$(curl -sS -c "$OTHER_COOKIE_JAR" -D "$OTHER_SIGNUP_HEADERS" -o "$OTHER_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $other_signup_code"
[ "$other_signup_code" = "200" ] || [ "$other_signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected secondary sign-up HTTP 200 or 201 got ${other_signup_code}"; exit 1; }

echo "PREREQ: sign in the secondary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_login_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -c "$OTHER_COOKIE_JAR" -D "$OTHER_LOGIN_HEADERS" -o "$OTHER_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $other_login_code"
[ "$other_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected secondary sign-in HTTP 200 got ${other_login_code}"; exit 1; }

i=1
while [ "$i" -le 7 ]; do
  title="task-${i}-${CASE_SUFFIX}"
  create_headers="/tmp/multiple_todos_retrieval_ordered_create_headers_${i}_${CASE_SUFFIX}.txt"
  create_body="/tmp/multiple_todos_retrieval_ordered_create_body_${i}_${CASE_SUFFIX}.txt"
  echo "PREREQ: create primary user todo ${title}"
  echo "REQUEST_HEADERS:"
  echo "Content-Type: application/json"
  echo "REQUEST_BODY: {\"title\":\"${title}\"}"
  create_code="$(curl -sS -b "$PRIMARY_COOKIE_JAR" -D "$create_headers" -o "$create_body" -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"${title}\"}" \
    "$BASE_URL/api/todos")"
  echo "RESPONSE_HEADERS:"
  cat "$create_headers"
  echo "RESPONSE_BODY:"
  cat "$create_body"
  echo
  echo "RESPONSE_STATUS: $create_code"
  [ "$create_code" = "200" ] || [ "$create_code" = "201" ] || { echo "ASSERTION_FAILED: expected primary create todo ${i} HTTP 200 or 201 got ${create_code}"; exit 1; }
  created_id="$(jq -r '.id // empty' "$create_body")"
  [ -n "$created_id" ] || { echo "ASSERTION_FAILED: expected primary create todo ${i} response to contain id"; exit 1; }
  PRIMARY_IDS="${PRIMARY_IDS} ${created_id}"
  i=$((i + 1))
done

echo "PREREQ: create one todo for the secondary user to verify filtering excludes other users"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"other-user-task-1-${CASE_SUFFIX}\"}"
other_create_headers="/tmp/multiple_todos_retrieval_ordered_other_create_headers_${CASE_SUFFIX}.txt"
other_create_body="/tmp/multiple_todos_retrieval_ordered_other_create_body_${CASE_SUFFIX}.txt"
other_create_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$other_create_headers" -o "$other_create_body" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"other-user-task-1-${CASE_SUFFIX}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$other_create_headers"
echo "RESPONSE_BODY:"
cat "$other_create_body"
echo
echo "RESPONSE_STATUS: $other_create_code"
[ "$other_create_code" = "200" ] || [ "$other_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected secondary create todo HTTP 200 or 201 got ${other_create_code}"; exit 1; }
OTHER_TODO_ID="$(jq -r '.id // empty' "$other_create_body")"
[ -n "$OTHER_TODO_ID" ] || { echo "ASSERTION_FAILED: expected secondary create todo response to contain id"; exit 1; }

# When

echo "STEP: When — retrieve the primary user's todo list after creating seven personal todos and one foreign todo"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -b "$PRIMARY_COOKIE_JAR" -D "$LIST_HEADERS" -o "$LIST_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then

echo "STEP: Then — verify the response contains exactly the seven primary-user todos and excludes other-user data"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
jq -e 'type == "array"' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected todo list response to be a JSON array"; exit 1; }
jq -e 'length == 7' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected exactly 7 todos for primary user"; exit 1; }
for n in 1 2 3 4 5 6 7; do
  title="task-${n}-${CASE_SUFFIX}"
  jq -e --arg title "$title" 'map(select(.title == $title)) | length == 1' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include ${title}"; exit 1; }
done
jq -e --arg title "other-user-task-1-${CASE_SUFFIX}" 'map(select(.title == $title)) | length == 0' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: response unexpectedly included secondary user todo title"; exit 1; }
jq -e --arg id "$OTHER_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 0' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: response unexpectedly included secondary user todo id ${OTHER_TODO_ID}"; exit 1; }

# Cleanup

echo "STEP: Cleanup — delete all created todos for both users"
for id in $PRIMARY_IDS; do
  if [ -n "$id" ]; then
    delete_headers="/tmp/multiple_todos_retrieval_ordered_delete_headers_${id}_${CASE_SUFFIX}.txt"
    delete_body="/tmp/multiple_todos_retrieval_ordered_delete_body_${id}_${CASE_SUFFIX}.txt"
    echo "PREREQ: delete primary user todo ${id}"
    delete_code="$(curl -sS -b "$PRIMARY_COOKIE_JAR" -D "$delete_headers" -o "$delete_body" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$id")"
    echo "RESPONSE_HEADERS:"
    cat "$delete_headers"
    echo "RESPONSE_BODY:"
    cat "$delete_body"
    echo
    echo "RESPONSE_STATUS: $delete_code"
    [ "$delete_code" = "200" ] || [ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected delete primary todo HTTP 200 or 404 got ${delete_code}"; exit 1; }
  fi
done
if [ -n "$OTHER_TODO_ID" ]; then
  other_delete_headers="/tmp/multiple_todos_retrieval_ordered_other_delete_headers_${CASE_SUFFIX}.txt"
  other_delete_body="/tmp/multiple_todos_retrieval_ordered_other_delete_body_${CASE_SUFFIX}.txt"
  echo "PREREQ: delete secondary user todo ${OTHER_TODO_ID}"
  other_delete_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$other_delete_headers" -o "$other_delete_body" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$OTHER_TODO_ID")"
  echo "RESPONSE_HEADERS:"
  cat "$other_delete_headers"
  echo "RESPONSE_BODY:"
  cat "$other_delete_body"
  echo
  echo "RESPONSE_STATUS: $other_delete_code"
  [ "$other_delete_code" = "200" ] || [ "$other_delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected secondary delete todo HTTP 200 or 404 got ${other_delete_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:multiple_todos_retrieval_ordered"
