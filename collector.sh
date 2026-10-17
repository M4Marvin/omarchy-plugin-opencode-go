#!/usr/bin/env bash
set -uo pipefail
AUTH_JSON="${OPENCODE_AUTH_JSON:-$HOME/.local/share/opencode/auth.json}"
URL=https://opencode.ai/zen/go/v1/usage
DB="$HOME/.local/share/opencode/opencode.db"

key=$(jq -r '. ["opencode-go"].key // empty' "$AUTH_JSON" 2>/dev/null || true)
# OpenCode v2 stores credentials in opencode.db (credential table) instead of auth.json
[[ -n $key ]] || key=$(sqlite3 -readonly "file:$DB?mode=ro" "SELECT json_extract(value,'\$.key') FROM credential WHERE integration_id='opencode-go' AND active=1 LIMIT 1;" 2>/dev/null || true)

collect() {
  local k=$1 out code
  [[ -n $k ]] || { echo '{"status":"No API key"}'; return; }
  out=$(curl -sS -m 10 -w $'\n%{http_code}' -H "Authorization: Bearer $k" "$URL" 2>/dev/null) || { echo '{"status":"network error"}'; return; }
  code=${out##*$'\n'}; out=${out%$'\n'*}
  [[ $code == 200 ]] || { jq -cn --arg s "HTTP $code" '{status:$s}'; return; }
  jq -e '.usage.rolling and .usage.weekly and .usage.monthly' >/dev/null 2>&1 <<<"$out" || { echo '{"status":"bad response"}'; return; }
  jq -c '{status:"ok",rolling:.usage.rolling,weekly:.usage.weekly,monthly:.usage.monthly}' <<<"$out"
}

windows=$(collect "$key")
status=$(jq -r '.status // empty' <<<"$windows")
error=''
[[ $status == ok ]] || error="$status"

cutoff=$(( $(date +%s)*1000-604800000 ))
recent='[]'
if [[ -r $DB ]]; then
  # OpenCode v2 keeps messages in session_message with a nested model object and no tokens.total
  if sqlite3 -readonly "file:$DB?mode=ro" "SELECT 1 FROM sqlite_master WHERE name='session_message';" 2>/dev/null | grep -q '^1$'; then
    q="SELECT date(time_created/1000,'unixepoch'),SUM(COALESCE(json_extract(data,'\$.tokens.total'),COALESCE(json_extract(data,'\$.tokens.input'),0)+COALESCE(json_extract(data,'\$.tokens.output'),0)+COALESCE(json_extract(data,'\$.tokens.reasoning'),0),0)),ROUND(SUM(COALESCE(json_extract(data,'\$.cost'),0)),4) FROM session_message WHERE time_created > $cutoff AND json_extract(data,'\$.model.providerID')='opencode-go' GROUP BY 1 ORDER BY 1;"
  else
    q="SELECT date(time_created/1000,'unixepoch'),SUM(COALESCE(json_extract(data,'\$.tokens.total'),0)),ROUND(SUM(COALESCE(json_extract(data,'\$.cost'),0)),4) FROM message WHERE time_created > $cutoff AND json_extract(data,'\$.providerID')='opencode-go' GROUP BY 1 ORDER BY 1;"
  fi
  rows=$(sqlite3 -readonly "file:$DB?mode=ro" "$q" 2>/dev/null || true)
  while IFS='|' read -r d t c; do [[ -n $d ]] && recent=$(jq -c --arg d "$d" --arg t "${t:-0}" --arg c "${c:-0}" '.+[{date:$d,tokens:($t|tonumber),cost:($c|tonumber)}]' <<<"$recent"); done <<<"$rows"
fi

jq -cn --arg label "Go" --argjson w "$windows" --argjson recent "$recent" --arg status "$status" --arg error "$error" '{label:$label,status:$status,rolling:$w.rolling,weekly:$w.weekly,monthly:$w.monthly,recentDays:$recent,updatedAt:(now|todateiso8601),error:$error}'
