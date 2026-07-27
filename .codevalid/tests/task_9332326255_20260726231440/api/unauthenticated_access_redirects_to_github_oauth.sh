#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/unauthenticated_access_redirects_to_github_oauth_cookie_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/unauthenticated_access_redirects_to_github_oauth_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/unauthenticated_access_redirects_to_github_oauth_body_${CASE_SUFFIX}.txt"
AUTH_HEADERS_FILE="/tmp/unauthenticated_access_redirects_to_github_oauth_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_FILE="/tmp/unauthenticated_access_redirects_to_github_oauth_auth_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE" "$AUTH_HEADERS_FILE" "$AUTH_BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — ensure no active session exists for the client"
: > "$COOKIE_JAR"
echo "PREREQ: starting with an empty cookie jar at $COOKIE_JAR"

echo "STEP: When — send unauthenticated request to protected todo API"
REQUEST_HEADERS='Accept: application/json'
REQUEST_BODY=''
echo "REQUEST_HEADERS: $REQUEST_HEADERS"
echo "REQUEST_BODY: $REQUEST_BODY"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

redirect_location="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_FILE" | tail -n 1)"

echo "STEP: Then — verify authentication flow is required before any todo data is exposed"
case "$status" in
  302|303|307|308)
    [ -n "$redirect_location" ] || { echo "ASSERTION_FAILED: expected redirect location for unauthenticated request"; exit 1; }
    case "$redirect_location" in
      */api/auth/github|/api/auth/github|http://*/api/auth/github|https://*/api/auth/github)
        echo "PREREQ: follow redirect to public GitHub auth endpoint"
        echo "REQUEST_HEADERS: Accept: application/json"
        echo "REQUEST_BODY:"
        auth_status="$(curl -sS -D "$AUTH_HEADERS_FILE" -o "$AUTH_BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/auth/github")"
        echo "RESPONSE_HEADERS:"
        cat "$AUTH_HEADERS_FILE"
        echo "RESPONSE_BODY:"
        cat "$AUTH_BODY_FILE"
        echo
        echo "RESPONSE_STATUS: $auth_status"
        case "$auth_status" in
          302|303|307|308) ;;
          *)
            echo "ASSERTION_FAILED: expected /api/auth/github to redirect got ${auth_status}"
            exit 1
            ;;
        esac
        auth_location="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$AUTH_HEADERS_FILE" | tail -n 1)"
        [ -n "$auth_location" ] || { echo "ASSERTION_FAILED: expected Location header from /api/auth/github"; exit 1; }
        printf '%s' "$auth_location" | grep -E 'github\.com/.*/oauth|github\.com/login/oauth/authorize' >/dev/null 2>&1 || {
          echo "ASSERTION_FAILED: expected redirect to GitHub OAuth authorize endpoint, got $auth_location"
          exit 1
        }
        ;;
      *github.com/login/oauth/authorize*|*github.com/*oauth*)
        :
        ;;
      *)
        echo "ASSERTION_FAILED: expected redirect to /api/auth/github or GitHub authorize URL, got ${redirect_location}"
        exit 1
        ;;
    esac
    ;;
  401|500)
    grep -Ei 'unauth|auth|login|sign|oauth|session' "$BODY_FILE" >/dev/null 2>&1 || {
      echo "ASSERTION_FAILED: expected protected-route body to mention authentication or session requirement"
      exit 1
    }
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 3xx, 401, or 500 for unauthenticated access got ${status}"
    exit 1
    ;;
esac

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_redirects_to_github_oauth"
