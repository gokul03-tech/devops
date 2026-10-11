#!/usr/bin/env bash
# End-to-end API verification using jq when available, otherwise Python's json module.
set -euo pipefail
BASE_URL="${BASE_URL:-http://127.0.0.1:5000}"
STAMP="$(date +%s)-$$"
EMAIL_A="smoke-learner-$STAMP@example.test"
EMAIL_B="smoke-tutor-$STAMP@example.test"
PASSWORD="PeerLearn-$STAMP"
SKILL="Smoke Python $STAMP"
OTHER_SKILL="Smoke Linux $STAMP"

if [[ -n "${PYTHON:-}" ]]; then :
elif command -v python3 >/dev/null 2>&1; then PYTHON=python3
elif command -v python >/dev/null 2>&1; then PYTHON=python
else echo "FAIL: Python is required for JSON parsing fallback." >&2; exit 1; fi

json_get() {
  local expression="$1"
  if command -v jq >/dev/null 2>&1; then jq -er "$expression"
  else "$PYTHON" -c 'import json,sys; v=json.load(sys.stdin); p=sys.argv[1].lstrip(".").split(".");
for k in p: v=v[int(k)] if isinstance(v,list) else v[k]
print(v)' "$expression"; fi
}
request() {
  local method="$1" path="$2" token="${3:-}" data="${4:-}"
  local args=(--fail --silent --show-error -X "$method" "$BASE_URL$path")
  if [[ -n "$token" ]]; then args+=(-H "Authorization: Bearer $token"); fi
  if [[ -n "$data" ]]; then args+=(-H 'Content-Type: application/json' --data "$data"); fi
  curl "${args[@]}"
}
step() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

health="$(request GET /api/health)" || fail "health endpoint"
[[ "$(printf '%s' "$health" | json_get .status)" == ok ]] || fail "health response payload"
step "health check"

user_a="$(request POST /api/auth/register '' "{\"name\":\"Smoke Learner $STAMP\",\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\",\"department\":\"Computing\"}")" || fail "register learner"
id_a="$(printf '%s' "$user_a" | json_get .user.id)"
step "register learner"
user_b="$(request POST /api/auth/register '' "{\"name\":\"Smoke Tutor $STAMP\",\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\",\"department\":\"Computing\"}")" || fail "register tutor"
id_b="$(printf '%s' "$user_b" | json_get .user.id)"
step "register partner"

login_a="$(request POST /api/auth/login '' "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")" || fail "login learner"
token_a="$(printf '%s' "$login_a" | json_get .token)"
step "login learner"
login_b="$(request POST /api/auth/login '' "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")" || fail "login tutor"
token_b="$(printf '%s' "$login_b" | json_get .token)"
step "login partner"

skill_b="$(request POST /api/profile/skills "$token_b" '' "{\"skill_name\":\"$SKILL\",\"skill_type\":\"teach\"}")" || fail "add taught skill"
skill_id="$(printf '%s' "$skill_b" | json_get .skill.id)"
step "partner adds teach skill"
request POST /api/profile/skills "$token_b" '' "{\"skill_name\":\"$OTHER_SKILL\",\"skill_type\":\"learn\"}" >/dev/null || fail "add partner learning skill"
request POST /api/profile/skills "$token_a" '' "{\"skill_name\":\"$OTHER_SKILL\",\"skill_type\":\"teach\"}" >/dev/null || fail "add learner taught skill"
request POST /api/profile/skills "$token_a" '' "{\"skill_name\":\"$SKILL\",\"skill_type\":\"learn\"}" >/dev/null || fail "add learner learning skill"
step "both users add reciprocal teach/learn skills"

matches="$(request GET "/api/matches?skill=$(printf '%s' "$SKILL" | sed 's/ /%20/g')" "$token_a")" || fail "get matches"
match_id="$(printf '%s' "$matches" | json_get .matches.0.id)"
match_type="$(printf '%s' "$matches" | json_get .matches.0.match_type)"
[[ "$match_id" == "$id_b" && "$match_type" == "Mutual Exchange" ]] || fail "mutual match result"
step "GET matches returns the expected Mutual Exchange"

session="$(request POST /api/sessions "$token_a" '' "{\"partner_id\":$id_b,\"skill_id\":$skill_id,\"proposed_time\":\"2030-01-20T16:00\",\"meeting_link\":\"https://example.test/session\"}")" || fail "create session request"
session_id="$(printf '%s' "$session" | json_get .session.id)"
step "create session request"
request PATCH "/api/sessions/$session_id" "$token_b" '{"action":"accept"}' >/dev/null || fail "accept session"
step "partner accepts session"
request PATCH "/api/sessions/$session_id" "$token_b" '{"action":"complete"}' >/dev/null || fail "complete session"
step "mark session complete"
request POST "/api/sessions/$session_id/review" "$token_a" '{"rating":5,"feedback":"Clear and useful session."}' >/dev/null || fail "submit review"
step "submit session review"
history="$(request GET /api/history "$token_a")" || fail "get history"
history_session="$(printf '%s' "$history" | json_get .history.0.session.id)"
[[ "$history_session" == "$session_id" ]] || fail "reviewed session appears in history"
step "GET history includes the completed reviewed session"
printf 'All smoke-test steps passed (learner %s, partner %s, session %s).\n' "$id_a" "$id_b" "$session_id"

