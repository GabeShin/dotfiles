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
source of truth for work across `iam`, `jaksam` and `agent-rotom`. Two views:
**Active** (`-status:Done`) and **Done** (`status:Done`), the history.

Canonical copy lives in `~/dotfiles/agent-skills/ticket-management`. **Don't edit
this file inside a repo** — edit dotfiles and re-run `sync-agent-skills.sh`.

Why the board is shaped this way, who Hermes is, and what isn't built yet:
`references/system-overview.md`.

## Fields

| Field         | Values                           | Meaning                                        |
| ------------- | -------------------------------- | ---------------------------------------------- |
| `Status`      | see below                        | Where the work stands.                         |
| `Project`     | `iam` · `jaksam` · `agent-rotom` | Set on every item, drafts included.            |
| `Priority`    | `P0` · `P1` · `P2`               |                                                |
| `Source`      | `me` · `hermes`                  | Who filed it.                                  |
| `Occurrences` | number                           | Times Hermes saw this Sentry issue. Unset ≠ 0. |
| `Last seen`   | date                             | Last time Hermes saw it.                       |

## Statuses

`Todo → In Progress → Deployed → In Monitor → Done`, with `Blocked` off to one side.

| Status        | Means                          | Set by                                                              |
| ------------- | ------------------------------ | ------------------------------------------------------------------- |
| `Todo`        | Filed and agreed. Not started. | Gabe or Hermes, at filing                                           |
| `In Progress` | Being worked right now.        | **you**                                                             |
| `Deployed`    | **Live.** Awaiting a monitor.  | **you** — or Gabe, when the ship is out of reach                    |
| `In Monitor`  | Sentry issue resolved; Sentry is watching for a regression. | Hermes — or Gabe                       |
| `Done`        | Nothing left to verify.        | Hermes — at cleanup, or after a clean window; Gabe when sweeping    |
| `Blocked`     | Waiting on something else.     | you, or Gabe                                                        |

## Your lane

**Claim at `In Progress` before the first edit. Finish at `Deployed`.**

Once you have confirmed the change is actually live — a deployment status, a hit
on the live URL, a published release, never "a merge usually deploys" — comment
saying which of exactly two things this ticket is, then set `Deployed`.

**Leave evidence, in one line of that comment** — something a reader can check
later, not your word for it. A web deploy: the live URL or deployment id. An
orchestrator: the deploy and restart. `jaksam`: the EAS update group and its
runtime, or the store release. You know it is live; the thread doesn't, and
Hermes will not resolve a Sentry issue on a ship it cannot see.

**It fixes a Sentry issue.** Name it:

```
Sentry issue: sentry:gabe-shin/jaksam-backup/<issue-id>
https://gabe-shin.sentry.io/issues/<issue-id>/
```

Hermes resolves that Sentry issue, moves the ticket to `In Monitor`, and Sentry's
own regression detection does the watching. If the issue comes back, Sentry
alerts, and Hermes returns the ticket to `Todo`.

Nothing else is the marker — not a `verify` block from the old convention, not a
prose link. If a ticket shipped before this contract, restate it in a new comment.

**On `jaksam`, add the runtime**: `Reach: runtime 1.8.0 only`. An OTA reaches one
version's installs; the rest keep emitting the events the fix removes, which
reads as a regression the moment the issue is resolved. That line is what lets a
recurrence be judged rather than guessed — see step 7 of the overview.

**It doesn't** — a feature, feedback, a refactor, docs. Say so in one line:
`No Sentry issue — feature work`. Hermes closes it out at cleanup.

`jaksam` (`gabe-shin/jaksam-backup`) and `iam` (`gabe-shin/iam`) both report to
Sentry; `agent-rotom` does not, so every ticket there takes the second branch,
which is expected rather than an oversight. On a repo that does report, the
branch is decided by the ticket: a fix for a real Sentry issue names it, while
feature work, refactors and docs still say `No Sentry issue`.

That is the whole contract. Don't write a monitoring spec, and **don't create a
Sentry alert for a ticket** — the regression alert already exists, and resolving
the issue is what arms it.

A ticket does not enter `In Monitor` because it *could* theoretically be
observed. Only a resolved Sentry issue gets watched; everything else goes
`Deployed → Done`.

**Marker in the body too, if the ticket is Sentry-derived.** The deployment
comment states what *this ship* resolves, but Hermes dedups at filing time —
before any deployment comment exists. A ticket whose only marker is in a comment
is invisible to the ticket-already-open check, and the next occurrence files a
duplicate. Hermes writes the body marker when it files; add it yourself if you
discover the Sentry link while diagnosing.

**Can't ship it yourself?** Merged but releasing later, as with an app-store
build: leave it `In Progress`, comment that it is merged and awaiting release,
naming the Sentry issue if there is one, and let whoever ships it set `Deployed`.
You hold the diagnosis and will be gone by release day.

**Blocked means say so.** Set `Blocked` and comment with what you're waiting on.
A stale `In Progress` with no comment is what makes the whole board
untrustworthy.

## Commands

```bash
scripts/board.sh next                      # open Todo items, most urgent first
scripts/board.sh get   <issue-url>         # this item's field values
scripts/board.sh set   <issue-url> Status "In Progress"
scripts/board.sh set   <issue-url> Occurrences 3
scripts/board.sh clear <issue-url> Occurrences
scripts/board.sh add   <issue-url>         # put an issue on the board (idempotent)
```

Names resolve at call time, so an unknown field or option is a loud error rather
than a silent no-op. Changing the Status options themselves goes through
`scripts/set-statuses.sh 'Name:COLOR:description' ...`, never a raw
`updateProjectV2Field`.

## Gotchas

- **`Fixes #N` closes the issue but doesn't move the board** — and here it
  shouldn't, since a merge isn't `Deployed`. Set status explicitly. The built-in
  `Item closed → Done` workflow is off on purpose.
- **Replacing Status options wipes every item's value** — the option is reissued
  a new id even when its name doesn't change. Use `set-statuses.sh`, which
  snapshots by name and restores, and refuses to run on a partial read.
- **Don't enable `Auto-archive items`.** It can't filter on `Status`, and the
  nearest filter it can express (`is:closed`) would archive the `Deployed` queue.
- **Board calls need the `project` scope** on the **`GabeShin`** account:
  `gh auth refresh -h github.com -s project`. If `gh auth status` shows
  `IamTaesub`, switch — that's the work account and can't see this board.

## Decision records

When the work made a choice someone would otherwise have to reconstruct — picked
between viable alternatives, changed a contract, rejected an approach someone
would retry — write `docs/decisions/YYYY-MM-DD-<slug>.md` from
`references/decision-record.md`. Not for an ordinary bug fix.

Repo docs: `docs/decisions/` (why), `docs/design/` (how), `docs/infra/` (deploy,
runtime, secrets).
