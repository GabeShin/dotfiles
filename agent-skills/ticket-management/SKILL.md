---
name: ticket-management
description: >
  How the Side Projects board is shaped and how to keep it truthful — the
  fields, the statuses, which status is expected at each stage of work, and the
  commands to read and set them. Use whenever picking up, working on, blocking,
  or finishing a ticket, or when asked "what's next".
---

# Ticket Management

The **Side Projects** board (https://github.com/users/GabeShin/projects/2) is the
source of truth for work across `iam`, `jaksam` and `agent-rotom`.

It has two views: **Active** (`-status:Done`) is the working board, and **Done**
(`status:Done`) is the history. Finished work is filtered off Active, never
deleted or archived — see the gotchas before reaching for archiving.

Canonical copy lives in `~/dotfiles/agent-skills/ticket-management`. **Don't edit
this file inside a repo** — edit dotfiles and re-run `sync-agent-skills.sh`.

For the whole picture — who Hermes is, what happens to a ticket after you let go
of it, and what isn't built yet — read `references/system-overview.md`.

## Fields

| Field         | Values                           | Meaning                                                                            |
| ------------- | -------------------------------- | ---------------------------------------------------------------------------------- |
| `Status`      | see below                        | Where the work stands.                                                             |
| `Project`     | `iam` · `jaksam` · `agent-rotom` | Which side project. Set on every item, including drafts, which have no repository. |
| `Priority`    | `P0` · `P1` · `P2`               |                                                                                    |
| `Source`      | `me` · `hermes`                  | Who filed it.                                                                      |
| `Occurrences` | number                           | How many times Hermes has seen this fingerprint. Unset ≠ zero.                     |
| `Last seen`   | date                             | Last time Hermes saw it.                                                           |

## Statuses

`Todo → In Progress → Deployed → In Monitor → Done`, with `Blocked` off to one side.

| Status        | Means                              | Set by                                           |
| ------------- | ---------------------------------- | ------------------------------------------------ |
| `Todo`        | Filed and agreed. Not started.     | Gabe or Hermes, at filing                        |
| `In Progress` | Being worked right now.            | **you**                                          |
| `Deployed`    | **Live.** Awaiting a monitor.      | **you** — or Gabe, when the ship is out of reach |
| `In Monitor`  | Hermes has a monitor running.      | Hermes — or Gabe                                 |
| `Done`        | Nothing left to verify.            | **you**, when nothing needs monitoring; Hermes after a clean window |
| `Blocked`     | Waiting on something else.         | you, or Gabe                                     |

**You claim at `In Progress`, and you finish at exactly one of `Deployed` or
`Done` — never both, and never one via the other.** Which one is decided by a
single question, asked once, after you have confirmed the change is live:
*is a monitor going to watch this?*

- **Yes** — set `Deployed`, with a verify block. Stop there. `In Monitor` is not
  yours to set, because it asserts a monitor is actually running and you have no
  way to know that; `board.sh` refuses it unless `BOARD_ALLOW_DOWNSTREAM=1`.
- **No** — and today this is most tickets — set `Done` directly, and say in the
  comment what made it unmonitorable. Don't route it through `Deployed` first:
  that column is a queue for a monitor, and adding to it work no monitor will
  ever read is how it stopped meaning anything.

Note the question is *"will a monitor watch this"*, not *"could anything about
this be observed"*. Almost any change is observable in principle. The one that
belongs in `Deployed` is the one with a signal something is actually going to
look at.

`Done` means **nothing is left to verify** — not "verified". Those collapse into
one status because the board only has to answer "does this still need someone's
attention?", and both answers are no. The cost is that the status alone no
longer tells you whether a fix was *checked*; the verify block on the ticket is
what tells you that. What `Done` must never mean is "I assume that worked": if a
monitor is going to watch it, the close-out is Hermes's call, not yours.

`Blocked` is off-flow and always yours to set.

## The rules that aren't obvious from the table

- **Claim before the first edit**, not after. An unclaimed ticket gets picked up
  twice — by you on another machine, or by another agent.
- **Only set `Deployed` or `Done` having actually confirmed it is live** — a
  checked deployment status, a hit on the live URL, a published release. Never
  because a merge usually deploys. Both statuses claim the change is running:
  `Deployed` is Hermes's cue to start watching, and a monitor pointed at code
  that isn't there manufactures a false regression, which is worse than no
  monitoring at all; `Done` on something that never shipped is simply a lie the
  board will not correct later.
- **If the ship is out of your reach** — merged but releasing later, as with an
  app-store build — leave it `In Progress` with a comment saying so, and let
  whoever ships it set `Deployed`. Write the verify block into that comment
  anyway, if the fix has a signal. You are the one holding the diagnosis and you
  will be gone by release day; whoever sets `Deployed` weeks later cannot write
  the block for you, and a `Deployed` item without one looks like an oversight.
- **Nothing to watch? Set `Done` and say why.** A refactor, a doc change, a
  layout fix, a dependency bump — most work has no runtime signal that would
  distinguish a working fix from a broken one. Closing it out is honest, and the
  comment is what makes it auditable: "nothing to monitor — this is a build-time
  assertion, and `npm run verify` covers it" is a reviewable claim. Silence is
  not.
- **When in doubt, `Deployed` with a block.** The cost of a monitor nobody runs
  yet is a ticket sitting in a column. The cost of a premature `Done` is a
  regression nobody is looking for.
- **Blocked means say so.** Set `Blocked` and comment with what you're waiting
  on. A stale `In Progress` with no comment is the one outcome that makes the
  whole board untrustworthy.

## The verification comment

When setting `Deployed`, comment on the issue with prose for Gabe and a
`verify` block for Hermes. If there is no monitorable signal there is no block
to write — set `Done` instead, with prose saying what made it unmonitorable.

````
Merged in abc1234. Root cause was the unawaited promise in `sync()`.

```verify
fingerprint: <the one from the filing, if this came from Hermes>
signal: sentry:7265214794
expect: zero occurrences
window: 72h
on-recurrence: reopen
watch: the sync path specifically, not every error in that file
```
````

| Key | |
|---|---|
| `fingerprint` | Ties this to the original finding. Omit if Gabe filed it. |
| `signal` | **Where** to look. |
| `expect` | What a pass looks like. |
| `window` | How long to watch, measured from `In Monitor` — not from merge. |
| `on-recurrence` | What Hermes does on a failure. |
| `watch` | **What counts**, where `signal` alone is too broad. Optional. |

**Every value is one line.** A wrapped value is silently dropped by a
line-based parser, and this block only works if it parses without a model.

A fenced block, not an HTML comment: a `-->` anywhere in a value would close a
comment early, dropping the rest of the contract into the rendered issue body.
Visible is also better — you can read the monitoring contract on the ticket
instead of taking its existence on trust.

## Commands

```bash
scripts/board.sh next                      # open Todo items, most urgent first
scripts/board.sh get   <issue-url>         # this item's field values
scripts/board.sh set   <issue-url> Status "In Progress"
scripts/board.sh set   <issue-url> Status Done      # nothing to monitor
scripts/board.sh set   <issue-url> Occurrences 3
scripts/board.sh clear <issue-url> Occurrences
scripts/board.sh add   <issue-url>         # put an issue on the board (idempotent)
```

Changing the Status options themselves goes through
`scripts/set-statuses.sh 'Name:COLOR:description' ...`, never a raw
`updateProjectV2Field` — see the gotchas below.

Field and option names are resolved at call time, so an unknown one is a loud
error rather than a silent no-op.

## Gotchas

**`Fixes #N` does not move the board — and here it shouldn't.** A merge does not
even mean `Deployed`, let alone `Done`, so the built-in `Item closed → Done`
workflow would be actively wrong on this board. Leave it off; set status
explicitly.

**Replacing Status options wipes every item's value.**
`updateProjectV2Field` replaces the whole option set, and re-listing a name is
not enough to keep it: the option is issued a new id, so items lose their value
even for names that never changed. `set-statuses.sh` snapshots by name, applies,
and restores — and refuses to touch the field unless its snapshot covered every
item, because a short read there is silent data loss rather than a degraded
result.

**Don't enable `Auto-archive items`.** Its filter understands only `is:`,
`reason:` and `updated:` — there is no `status:`, so "archive what's `Done`" is
precisely what it cannot express. The nearest thing you can write,
`is:closed updated:@today-2w`, is actively harmful here: most `Deployed` items
are closed issues (`Fixes #N` closes on merge), so it would archive the queue
Hermes reads, and archived items drop out of `items()` by default. `Done` is
kept off the Active view by a view filter instead.

**Board calls need the `project` scope** on the **`GabeShin`** account:
`gh auth refresh -h github.com -s project`. If `gh auth status` shows
`IamTaesub` active, switch — that's the work account and can't see this board.

## Decision records

When the work made a choice someone would otherwise have to reconstruct — picked
between viable alternatives, changed a contract, rejected an approach someone
would retry, or accepted a known tradeoff — write
`docs/decisions/YYYY-MM-DD-<slug>.md` from `references/decision-record.md`.
Not for an ordinary bug fix with one sensible resolution.

Repo doc structure: `docs/decisions/` (why), `docs/design/` (how), `docs/infra/`
(deploy, runtime, secrets).
