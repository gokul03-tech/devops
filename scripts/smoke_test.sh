#!/usr/bin/env bash
# Exercise the public API from registration through post-session feedback.
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:5000}"
STAMP="$(date +%s)"
SKILL_NAME="SmokeTest${STAMP}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

post_json() {
  local path="$1" body="$2" token="${3:-}"
  if [[ -n "$token" ]]; then
    curl --fail --silent --show-error -H 'Content-Type: application/json' -H "Authorization: Bearer $token" -d "$body" "$BASE_URL$path"
  else
    curl --fail --silent --show-error -H 'Content-Type: application/json' -d "$body" "$BASE_URL$path"
  fi
}
patch_json() {
  curl --fail --silent --show-error -X PATCH -H 'Content-Type: application/json' -H "Authorization: Bearer $3" -d "$2" "$BASE_URL$1"
}
json_value() {
  python3 -c 'import json,sys; value=json.load(sys.stdin); path=sys.argv[1].split(".");
for key in path: value=value[int(key)] if isinstance(value,list) else value[key]
print(value)' "$1"
}

first="$(post_json /api/auth/register "{\"name\":\"Smoke Learner $STAMP\",\"email\":\"smoke-$STAMP@example.test\",\"password\":\"${STAMP}StrongPass!\",\"department\":\"Computing\"}")"
second="$(post_json /api/auth/register "{\"name\":\"Smoke Tutor $STAMP\",\"email\":\"tutor-$STAMP@example.test\",\"password\":\"${STAMP}StrongPass!\",\"department\":\"Computing\"}")"
LEARNER_TOKEN="$(printf '%s' "$first" | json_value token)"
TUTOR_TOKEN="$(printf '%s' "$second" | json_value token)"
TUTOR_ID="$(printf '%s' "$second" | json_value user.id)"
LEARNER_ID="$(printf '%s' "$first" | json_value user.id)"
SKILL="$(post_json /api/profile/skills "{\"skill_name\":\"$SKILL_NAME\",\"skill_type\":\"teach\"}" "$TUTOR_TOKEN")"
SKILL_ID="$(printf '%s' "$SKILL" | json_value skill.id)"
post_json /api/profile/skills '{"skill_name":"Linux","skill_type":"teach"}' "$LEARNER_TOKEN" >/dev/null
matches="$(curl --fail --silent --show-error -H "Authorization: Bearer $LEARNER_TOKEN" "$BASE_URL/api/matches?skill=$SKILL_NAME")"
MATCH_ID="$(printf '%s' "$matches" | json_value matches.0.id)"
[[ "$MATCH_ID" == "$TUTOR_ID" ]]
session="$(post_json /api/sessions "{\"partner_id\":$TUTOR_ID,\"skill_id\":$SKILL_ID,\"proposed_time\":\"Tomorrow at 4pm\"}" "$LEARNER_TOKEN")"
SESSION_ID="$(printf '%s' "$session" | json_value session.id)"
patch_json "/api/sessions/$SESSION_ID" '{"action":"accept"}' "$TUTOR_TOKEN" >/dev/null
patch_json "/api/sessions/$SESSION_ID" '{"action":"complete"}' "$TUTOR_TOKEN" >/dev/null
post_json "/api/sessions/$SESSION_ID/review" '{"rating":5,"feedback":"Clear and useful session."}' "$LEARNER_TOKEN" >/dev/null
curl --fail --silent --show-error "$BASE_URL/api/health"
printf '\nSmoke test passed (learner %s, tutor %s, session %s).\n' "$LEARNER_ID" "$TUTOR_ID" "$SESSION_ID"
