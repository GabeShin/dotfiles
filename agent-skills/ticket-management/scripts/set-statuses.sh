#!/usr/bin/env bash
# Replace the board's Status options without losing every item's value.
#
#   set-statuses.sh "Todo:BLUE:Filed and agreed" "In Progress:YELLOW:Being worked" ...
#
# `updateProjectV2Field` replaces the entire option set, and re-listing a name
# is NOT enough to preserve it -- the option is issued a new id, so every item's
# value is dropped even for options whose name never changed. So: snapshot
# item -> status *name* first, apply, then re-apply by name. Any item whose
# status name no longer exists is reported rather than silently left blank.
set -euo pipefail

OWNER="${BOARD_OWNER:-GabeShin}"
NUMBER="${BOARD_NUMBER:-2}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ $# -eq 0 ] && { echo "usage: $(basename "$0") 'Name:COLOR:description'..." >&2; exit 2; }

FIELD_ID="$(gh api graphql -f owner="$OWNER" -F number="$NUMBER" -f query='
  query($owner:String!,$number:Int!){ user(login:$owner){ projectV2(number:$number){
    field(name:"Status"){ ... on ProjectV2SingleSelectField { id } } } } }' \
  --jq '.data.user.projectV2.field.id')"

echo "==> snapshot"
SNAP="$(gh api graphql -f owner="$OWNER" -F number="$NUMBER" -f query='
  query($owner:String!,$number:Int!){ user(login:$owner){ projectV2(number:$number){
    items(first:100){ nodes{
      content{ ... on Issue { url } }
      fieldValues(first:30){ nodes{ ... on ProjectV2ItemFieldSingleSelectValue {
        name field{ ... on ProjectV2FieldCommon{name} } } } } } } } } }' \
| python3 -c "
import sys,json
for n in json.load(sys.stdin)['data']['user']['projectV2']['items']['nodes']:
    c=n.get('content') or {}
    if not c.get('url'): continue
    fv={v['field']['name']:v['name'] for v in n['fieldValues']['nodes'] if v and 'field' in v}
    if fv.get('Status'): print(c['url'], fv['Status'], sep='\t')
")"
printf '%s' "$SNAP" | sed 's/^/    /'

echo "==> applying $# options"
OPTS="$(python3 - "$@" <<'PY'
import sys
out=[]
for spec in sys.argv[1:]:
    name,color,desc = (spec.split(':',2)+['GRAY',''])[:3]
    out.append('{name:"%s",color:%s,description:"%s"}' % (name, color, desc.replace('"','\\"')))
print('['+' '.join(out)+']')
PY
)"
gh api graphql -f query="mutation{ updateProjectV2Field(input:{
    fieldId:\"$FIELD_ID\" singleSelectOptions:$OPTS
  }){ projectV2Field{ ... on ProjectV2SingleSelectField{ options{ name } } } } }" \
| python3 -c "
import sys,json
print('    '+' -> '.join(o['name'] for o in json.load(sys.stdin)['data']['updateProjectV2Field']['projectV2Field']['options']))"

echo "==> restoring"
# Re-applying a snapshot legitimately covers every status, including the
# downstream ones board_set guards. Without this the restore would silently
# skip anything that had been In Monitor or Done and report it as a missing
# option.
export BOARD_ALLOW_DOWNSTREAM=1
# shellcheck source=board.sh
source "$HERE/board.sh"
missing=0
while IFS=$'\t' read -r url status; do
  [ -z "${url:-}" ] && continue
  if board_set "$url" Status "$status" >/dev/null 2>&1; then
    echo "    $url -> $status"
  else
    echo "    !! $url had '$status', which no longer exists -- now unset" >&2
    missing=$((missing+1))
  fi
done <<< "$SNAP"

[ "$missing" -gt 0 ] && echo "==> $missing item(s) need a status set by hand" >&2
exit 0
