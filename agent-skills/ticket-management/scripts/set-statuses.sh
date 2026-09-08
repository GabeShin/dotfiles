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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=board.sh
source "$HERE/board.sh"

# Archived items hold field values too, and this mutation would wipe them just
# the same, so the snapshot has to see them.
ALL_STATES='[ARCHIVED, NOT_ARCHIVED]'

[ $# -eq 0 ] && { echo "usage: $(basename "$0") 'Name:COLOR:description'..." >&2; exit 2; }

FIELD_ID="$(gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query='
  query($owner:String!,$number:Int!){ user(login:$owner){ projectV2(number:$number){
    field(name:"Status"){ ... on ProjectV2SingleSelectField { id } } } } }' \
  --jq '.data.user.projectV2.field.id')"

echo "==> snapshot"
# Paged, and then checked against totalCount. A partial snapshot is not a
# degraded result here, it is silent data loss: every item it failed to see
# loses its Status the moment the mutation below runs. So refuse to proceed
# unless the read demonstrably covered the whole board.
RAW="$(_board_items '
      content{ ... on Issue { url } ... on PullRequest { url } }
      fieldValues(first:30){ nodes{ ... on ProjectV2ItemFieldSingleSelectValue {
        name field{ ... on ProjectV2FieldCommon{name} } } } }' '' "$ALL_STATES")"

PAGED="$(printf '%s\n' "$RAW" | grep -c . || true)"
TOTAL="$(_board_item_total "$ALL_STATES")"
if [ "$PAGED" -ne "$TOTAL" ]; then
  echo "set-statuses: read $PAGED of $TOTAL items -- refusing to touch the field." >&2
  echo "  Applying the option set now would blank the Status of everything the" >&2
  echo "  snapshot missed. Re-run; if it persists, the paging is broken." >&2
  exit 1
fi
echo "    read $PAGED/$TOTAL items"

SNAP="$(printf '%s\n' "$RAW" | python3 -c '
import sys,json
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    n=json.loads(line)
    c=n.get("content") or {}
    if not c.get("url"): continue
    fv={v["field"]["name"]:v["name"] for v in n["fieldValues"]["nodes"] if v and "field" in v}
    if fv.get("Status"): print(c["url"], fv["Status"], sep="\t")
')"
printf '%s\n' "$SNAP" | sed 's/^/    /'
echo "    $(printf '%s\n' "$SNAP" | grep -c . || true) item(s) carry a Status"

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
# downstream ones board_set guards. Only In Monitor is guarded now, but without
# this the restore would refuse anything that had been In Monitor and report it
# as a missing option.
export BOARD_ALLOW_DOWNSTREAM=1
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
