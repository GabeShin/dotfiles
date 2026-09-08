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

# _board_items <node-selection> [search-query] -> one JSON object per line
#
# GitHub caps a page at 100 items, so anything that must see the whole board
# has to follow the cursor. A bare items(first:100) does not fail when the
# board outgrows it -- it silently returns a prefix, which is how a truncated
# read turns into a wrong answer. Pass a search query to narrow server-side
# (`status:Todo is:open`) rather than fetching everything and filtering here.
_board_items() {
  local nodesel="$1" q="${2:-}" states="${3:-}" cursor="" after resp out arch=""
  # Default (NOT_ARCHIVED) is right for reads that mirror a view; pass
  # '[ARCHIVED, NOT_ARCHIVED]' for reads that must be exhaustive, since an
  # archived item still holds field values that a field rewrite would wipe.
  [ -n "$states" ] && arch=", archivedStates: $states"
  while :; do
    after=""
    [ -n "$cursor" ] && after=", after: \"$cursor\""
    resp="$(gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query="
      query(\$owner:String!,\$number:Int!){
        user(login:\$owner){ projectV2(number:\$number){
          items(first:100${after}${arch}, query: \"$q\"){
            pageInfo{ hasNextPage endCursor }
            nodes{ $nodesel } } } } }")"
    # One pass emits the next cursor on line 1, then the nodes -- so a page
    # costs a single parse rather than two.
    out="$(printf '%s' "$resp" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]["user"]["projectV2"]["items"]
pi=d["pageInfo"]
print(pi["endCursor"] if pi["hasNextPage"] else "")
for n in d["nodes"]: print(json.dumps(n))
')"
    cursor="$(printf '%s\n' "$out" | sed -n 1p)"
    printf '%s\n' "$out" | tail -n +2
    [ -z "$cursor" ] && break
  done
}

# _board_item_total -> how many items the board holds, archived included.
# Used to prove an exhaustive read actually was exhaustive.
_board_item_total() {
  local states="${1:-}" arch=""
  [ -n "$states" ] && arch=", archivedStates: $states"
  gh api graphql -f owner="$BOARD_OWNER" -F number="$BOARD_NUMBER" -f query="
    query(\$owner:String!,\$number:Int!){ user(login:\$owner){ projectV2(number:\$number){
      items(first:1${arch}){ totalCount } } } }" \
    --jq '.data.user.projectV2.items.totalCount'
}

# board_item_id <issue-url> -> the project item id, or empty if not on the board
#
# Asked of the *issue*, not by scanning the project: an issue belongs to a
# handful of projects, while the project accumulates every ticket ever filed.
# The scan this replaces read items(first:100) unpaged, so past 100 items the
# lookup began missing -- and board_add reads a miss as "not on the board" and
# adds a second item for the same issue. includeArchived is there for the same
# reason: an archived ticket is still on the board, and re-adding it would
# duplicate it.
board_item_id() {
  local url="$1" iid
  iid="$(gh issue view "$url" --json id --jq .id)"
  # PullRequest as well as Issue: `gh issue view` resolves a PR number too, and
  # then `... on Issue` matches nothing, leaving projectItems absent. The `[]?`
  # is what makes an absent or null path an empty result instead of a jq error
  # -- board_add reads the empty string as "not on the board", and a hard error
  # here would abort board_set through set -e.
  gh api graphql -f id="$iid" -f query='
    query($id:ID!){ node(id:$id){
      ... on Issue       { projectItems(first:50, includeArchived:true){ nodes{ id project{ number } } } }
      ... on PullRequest { projectItems(first:50, includeArchived:true){ nodes{ id project{ number } } } } } }' \
    --jq "[.data.node.projectItems.nodes[]? | select(.project.number == $BOARD_NUMBER) | .id][0] // \"\""
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

  # 'In Monitor' asserts a fact an agent cannot know -- that a monitor is
  # actually running. That one stays Hermes's alone. Prose in SKILL.md says so;
  # this is the part that holds when the prose is skimmed.
  #
  # 'Done' is deliberately NOT guarded. It means "no verification is pending",
  # which is true in two ways: Hermes watched a clean window, or there was never
  # anything to watch. The second case is most tickets, and guarding it parked
  # that work in 'Deployed' forever, waiting on a transition from a monitoring
  # agent that does not exist yet. The tradeoff is real and recorded in
  # docs/decisions/2026-09-04-agents-close-unmonitored-tickets.md in the iam
  # repo: nothing here can tell a considered 'nothing to monitor' from an agent
  # closing its own ticket early.
  if [ "$field" = "Status" ] && [ "${BOARD_ALLOW_DOWNSTREAM:-0}" != "1" ]; then
    case "$value" in
      "In Monitor")
        echo "board_set: refusing to set Status='In Monitor' -- that is Hermes's transition." >&2
        echo "  It asserts a monitor is running, which you cannot know. Set" >&2
        echo "  'Deployed' with a verify block and let Hermes pick it up, or set" >&2
        echo "  'Done' if there is nothing to monitor. BOARD_ALLOW_DOWNSTREAM=1" >&2
        echo "  overrides this only if you are Hermes." >&2
        return 1 ;;
      "Done")
        echo "board_set: Status='Done' -- assuming nothing needs monitoring." >&2
        echo "  If this fix does have a monitorable signal, set 'Deployed' with a" >&2
        echo "  verify block instead and leave the close-out to Hermes." >&2
        ;;
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
#
# Narrowed server-side to Todo. The Status check below is kept as a second
# line of defence: the search qualifiers are GitHub's, not ours, and a silent
# change there should show up as a missing row rather than a wrong one.
board_next() {
  _board_items '
          content{ ... on Issue { number title url state repository{name} } }
          fieldValues(first:30){ nodes{
            ... on ProjectV2ItemFieldSingleSelectValue { name field{ ... on ProjectV2FieldCommon{name} } } } }' \
      'status:Todo is:open' \
    | python3 -c '
import sys,json
rank={"P0":0,"P1":1,"P2":2,None:3}
rows=[]
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    n=json.loads(line)
    c=n.get("content") or {}
    if not c or c.get("state")!="OPEN": continue
    fv={v["field"]["name"]:v["name"] for v in n["fieldValues"]["nodes"] if v and "field" in v}
    if fv.get("Status")!="Todo": continue
    rows.append((rank.get(fv.get("Priority"),3), fv, c))
for _,fv,c in sorted(rows, key=lambda r: r[0]):
    pri = fv.get("Priority") or "--"
    proj = fv.get("Project") or "?"
    src = fv.get("Source") or "?"
    num, title, url = c["number"], c["title"], c["url"]
    print(f"  [{pri}] {proj:<12} #{num:<5} {title}")
    st = fv.get("Status")
    print(f"        {url}  (Status={st}, Source={src})")
'
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
