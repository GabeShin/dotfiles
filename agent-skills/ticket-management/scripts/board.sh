#!/usr/bin/env bash
# Read and write the Side Projects board by field *name*.
#
# Field and option ids are per-project opaque strings, so hardcoding them
# would break the moment the board is rebuilt. Everything here resolves by
# name at call time and caches the lookup for the life of the process.
#
#   board_set <issue-url> Status "In Progress"
#   board_set <issue-url> Occurrences 3
#   board_get <issue-url>
#
# Requires: gh with the `project` scope (gh auth refresh -h github.com -s project)
set -euo pipefail

BOARD_OWNER="${BOARD_OWNER:-GabeShin}"
BOARD_NUMBER="${BOARD_NUMBER:-2}"

_BOARD_CACHE=""

_board_meta() {
  if [ -z "$_BOARD_CACHE" ]; then
    _BOARD_CACHE="$(gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query='
      query($owner:String!,$number:Int!){
        user(login:$owner){ projectV2(number:$number){ id
          fields(first:50){ nodes{
            ... on ProjectV2SingleSelectField { id name dataType options{ id name } }
            ... on ProjectV2FieldCommon { id name dataType } } } } } }')"
  fi
  printf '%s' "$_BOARD_CACHE"
}

board_project_id() {
  _board_meta | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["user"]["projectV2"]["id"])'
}

# board_item_id <issue-url> -> the project item id, or empty if not on the board
board_item_id() {
  local url="$1" cid
  cid="$(gh issue view "$url" --json id --jq .id)"
  gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query='
    query($owner:String!,$number:Int!){
      user(login:$owner){ projectV2(number:$number){
        items(first:100){ nodes{ id content{ ... on Issue { id } } } } } } }' \
    | python3 -c "
import sys,json
want='$cid'
for n in json.load(sys.stdin)['data']['user']['projectV2']['items']['nodes']:
    if (n.get('content') or {}).get('id')==want: print(n['id']); break
"
}

# board_add <issue-url> -> item id (idempotent; returns the existing item if present)
board_add() {
  local url="$1" existing cid
  existing="$(board_item_id "$url")"
  if [ -n "$existing" ]; then printf '%s' "$existing"; return; fi
  cid="$(gh issue view "$url" --json id --jq .id)"
  gh api graphql -f pid="$(board_project_id)" -f cid="$cid" -f query='
    mutation($pid:ID!,$cid:ID!){ addProjectV2ItemById(input:{projectId:$pid,contentId:$cid}){ item{ id } } }' \
    --jq '.data.addProjectV2ItemById.item.id'
}

# board_set <issue-url> <field-name> <value>
# Single-select values are matched against the option names; everything else is
# written as the field's own type. An unknown field or option is a hard error
# rather than a silent no-op, because a silently unset Status is worse than a
# failed run.
board_set() {
  local url="$1" field="$2" value="$3" item

  # A coding agent's lane is Todo -> In Progress -> Deployed. Everything past
  # Deployed belongs to Hermes, which asserts things an agent cannot know: that
  # a monitor exists, and that a clean window has passed. Prose in SKILL.md says
  # so; this is the part that holds when the prose is skimmed.
  if [ "$field" = "Status" ] && [ "${BOARD_ALLOW_DOWNSTREAM:-0}" != "1" ]; then
    case "$value" in
      "In Monitor"|"Done")
        echo "board_set: refusing to set Status='$value' -- that is Hermes's transition." >&2
        echo "  A coding agent stops at 'Deployed' and omits the verify block if" >&2
        echo "  nothing needs watching. Set BOARD_ALLOW_DOWNSTREAM=1 only if you" >&2
        echo "  are Hermes or are deliberately sweeping the board by hand." >&2
        return 1 ;;
    esac
  fi

  item="$(board_add "$url")"
  local spec
  spec="$(_board_meta | python3 -c "
import sys,json
want='''$field'''; val='''$value'''
fs=json.load(sys.stdin)['data']['user']['projectV2']['fields']['nodes']
f=next((x for x in fs if x and x.get('name')==want), None)
if not f: sys.exit(f'board_set: no field named {want!r}')
dt=f.get('dataType')
if dt=='SINGLE_SELECT':
    o=next((o for o in f['options'] if o['name']==val), None)
    if not o: sys.exit(f'board_set: {want!r} has no option {val!r} (have: '+', '.join(o['name'] for o in f['options'])+')')
    print(f[\"id\"]); print('singleSelectOptionId'); print(o['id'])
else:
    print(f['id'])
    print({'NUMBER':'number','DATE':'date','TEXT':'text'}.get(dt,'text'))
    print(val)
")"
  local fid key val
  fid="$(sed -n 1p <<<"$spec")"; key="$(sed -n 2p <<<"$spec")"; val="$(sed -n 3p <<<"$spec")"

  # GraphQL input-object keys are names, not strings -- they must not be quoted.
  local valuejson
  case "$key" in
    number) valuejson="{number: $val}" ;;
    *)      valuejson="{$key: \"$val\"}" ;;
  esac

  gh api graphql -f query="mutation{ updateProjectV2ItemFieldValue(input:{
      projectId:\"$(board_project_id)\", itemId:\"$item\",
      fieldId:\"$fid\", value: $valuejson }){ projectV2Item{ id } } }" >/dev/null
  echo "board: $field = $value"
}

# board_clear <issue-url> <field-name> -- unset a field entirely.
# Distinct from writing 0 or "": an unmeasured Occurrences must stay
# distinguishable from a measured zero.
board_clear() {
  local url="$1" field="$2" item fid
  item="$(board_add "$url")"
  fid="$(_board_meta | python3 -c "
import sys,json
want='''$field'''
fs=json.load(sys.stdin)['data']['user']['projectV2']['fields']['nodes']
f=next((x for x in fs if x and x.get('name')==want), None)
if not f: sys.exit(f'board_clear: no field named {want!r}')
print(f['id'])")"
  gh api graphql -f pid="$(board_project_id)" -f item="$item" -f fid="$fid" -f query='
    mutation($pid:ID!,$item:ID!,$fid:ID!){
      clearProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$item,fieldId:$fid}){ projectV2Item{ id } } }' >/dev/null
  echo "board: $field cleared"
}

# board_get <issue-url> -> the item's current field values
board_get() {
  local url="$1" item
  item="$(board_item_id "$url")"
  [ -z "$item" ] && { echo "not on the board"; return; }
  gh api graphql -f id="$item" -f query='
    query($id:ID!){ node(id:$id){ ... on ProjectV2Item {
      fieldValues(first:30){ nodes{
        ... on ProjectV2ItemFieldSingleSelectValue { name field{ ... on ProjectV2FieldCommon{name} } }
        ... on ProjectV2ItemFieldNumberValue      { number field{ ... on ProjectV2FieldCommon{name} } }
        ... on ProjectV2ItemFieldDateValue        { date field{ ... on ProjectV2FieldCommon{name} } }
        ... on ProjectV2ItemFieldTextValue        { text field{ ... on ProjectV2FieldCommon{name} } } } } } } }' \
    | python3 -c "
import sys,json
for v in json.load(sys.stdin)['data']['node']['fieldValues']['nodes']:
    if not v or 'field' not in v: continue
    val=v.get('name') or v.get('number') or v.get('date') or v.get('text')
    print(f\"  {v['field']['name']}: {val}\")
"
}

# board_next -> open Todo items, most urgent first
board_next() {
  gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query='
    query($owner:String!,$number:Int!){
      user(login:$owner){ projectV2(number:$number){
        items(first:100){ nodes{
          content{ ... on Issue { number title url state repository{name} } }
          fieldValues(first:30){ nodes{
            ... on ProjectV2ItemFieldSingleSelectValue { name field{ ... on ProjectV2FieldCommon{name} } } } } } } } } }' \
    | python3 -c "
import sys,json
rank={'P0':0,'P1':1,'P2':2,None:3}
rows=[]
for n in json.load(sys.stdin)['data']['user']['projectV2']['items']['nodes']:
    c=n.get('content') or {}
    if not c or c.get('state')!='OPEN': continue
    fv={v['field']['name']:v['name'] for v in n['fieldValues']['nodes'] if v and 'field' in v}
    if fv.get('Status') not in ('Todo',): continue
    rows.append((rank.get(fv.get('Priority'),3), fv, c))
for _,fv,c in sorted(rows, key=lambda r: r[0]):
    print(f\"  [{fv.get('Priority','--')}] {fv.get('Project','?'):<12} #{c['number']:<5} {c['title']}\")
    print(f\"        {c['url']}  (Status={fv.get('Status')}, Source={fv.get('Source','?')})\")
"
}

# Allow use as a CLI as well as a sourced library: board.sh set <url> Status Done
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-}"; shift || true
  case "$cmd" in
    set)   board_set "$@" ;;
    clear) board_clear "$@" ;;
    get)  board_get "$@" ;;
    add)  board_add "$@" ;;
    next) board_next ;;
    *) echo "usage: board.sh {set <url> <field> <value>|clear <url> <field>|get <url>|add <url>|next}" >&2; exit 2 ;;
  esac
fi
