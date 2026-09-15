# The whole picture

Why the board is shaped the way it is, and what happens to a ticket after you
let go of it. `SKILL.md` is the contract; this is the reasoning behind it.

## Three actors

**Hermes** is the eyes — a [Nous Research Hermes Agent](https://github.com/NousResearch/hermes-agent)
on Gabe's always-on machine, running monitoring jobs over the live software. It
notices problems, files them, and after a fix ships checks whether the problem
stopped. It is the only actor that can assert "verified", because it is the only
one still watching once everyone else has moved on.

**Gabe** decides: what gets built, what matters, what ships. He files tickets,
sets priority, triages what Hermes finds, and performs the releases the other two
cannot.

**You** do the work — take an agreed ticket, implement it, get it live, hand it
on. You are the only actor holding the diagnosis at the moment the fix ships,
which is why naming the Sentry issue the fix resolves is yours to do. Hermes
knows how to watch; only you know what this change was supposed to close.

## Why one board across three repos

It answers a question no single repo can: _of everything I could work on
tonight, what matters most?_ Views compose downward, not upward — one board
filters to a single repo trivially, three boards don't compose into one list.

It is also where three writers meet: Gabe from a phone, Hermes from a monitor,
an agent noting something in passing. `Source` records which.

## The lifecycle

1. **Hermes finds something.** The Sentry issue id _is_ the fingerprint — a
   stable identity for the problem, not for the prose describing it — and it
   searches the board for that marker. Open → bump `Occurrences` and `Last seen`,
   stay quiet. **Declined** → nothing, ever. New → file at `Todo`,
   `Source=hermes`, with the marker in the body.
2. **It posts to Slack.** High priority immediately, the rest in a digest: a
   channel that pings on every finding gets muted, and a muted channel breaks the
   design at step one.
3. **Gabe triages**, setting `Priority`. Anything you need to know goes on the
   _issue_ — the ticket is the context surface, Slack is a view of it.
4. **You claim it** at `In Progress`, implement, and get it live.
5. **You finish** at `Deployed`, commenting either the `Sentry issue:` marker or
   one line saying there isn't one.
6. **Hermes reads that comment.** Marker → it resolves the Sentry issue and moves
   the ticket to `In Monitor`. No marker → it closes the ticket out at cleanup,
   `Deployed → Done`.
7. **Sentry watches.** A resolved issue that recurs is a regression, and Sentry
   already alerts on that — Hermes correlates the alert back to the ticket by its
   marker and returns it to `Todo`, reopened.

Step 7 is the payoff: the ticket ends up holding the diagnosis, the fix, the
Sentry issue it was meant to close, and whether it stayed closed — so when the
thing recurs in six months, it answers what was already tried.

## Who may do what

|        | Files | `Todo`–`Deployed` | `In Monitor` | `Done` | Closes         | Reopens |
| ------ | ----- | ----------------- | ------------ | ------ | -------------- | ------- |
| Gabe   | yes   | yes               | yes          | yes    | yes            | yes     |
| You    | yes   | to `Deployed`     | **no**       | **no** | via `Fixes #N` | no      |
| Hermes | yes   | `Todo` only       | yes          | yes    | **never**      | yes     |

Hermes never closes: a bug in a monitoring job must not be able to hide real
work. Reopening is safe — it only ever surfaces something.

You never set `In Monitor`: it asserts a Sentry issue has been resolved and is
being watched, which is Hermes's action to take and yours only to enable, by
naming the issue. `board.sh` enforces it. `Done` is Hermes's too — it means the
ticket has been through cleanup or a clean window, and neither is something you
can observe from inside the session that shipped the change.

## Invariants

- **One source of truth.** Board holds state, issue holds detail, Slack is a
  view. A second store — a `docs/todo.md`, a Hermes-local list — drifts, and the
  board stops being believable.
- **Merged ≠ deployed ≠ verified.** Three facts, three statuses. This is why the
  built-in `Item closed → Done` workflow stays off.
- **`In Monitor` asserts a resolved Sentry issue.** That's why it is separate
  from `Deployed`: if Hermes is down, work piles up visibly rather than sitting
  in a column implying a watch nobody performs. It is a checkable claim now — a
  ticket is in `In Monitor` only if some Sentry issue is actually resolved and
  armed for regression.
- **The monitor is Sentry's, not ours.** Resolving an issue is what arms its
  regression detection, so a ticket needs no alert of its own. Per-ticket alert
  rules would accumulate, need pruning, and fire on top of the alert that
  already exists.
- **Dedup on the Sentry issue id, never on prose.** Two phrasings of one bug file
  it twice; an exact-match marker doesn't. The marker has to be in the issue
  **body** for this, because dedup runs at filing — a marker that appears only in
  a deployment comment arrives several steps too late to prevent the duplicate.
- **Declined means never again.** Otherwise closing a false positive just invites
  Hermes to re-file it.
- **Unmeasurable is not verified.** A ticket with no Sentry issue is closed as
  _nothing to watch_, never as _checked_. A low-traffic project may never
  exercise a path, and silence on a dead path proves nothing.
- **Nothing leaves the board on a timer.** `Done` accumulates, and should — it is
  the history that answers "what was already tried". It is hidden by a view
  filter, not archived: archived items fall out of `items()` by default, which is
  how a ticket goes invisible to both `board.sh` and a fingerprint search,
  breaking "declined means never again".

## The repos differ in one way that matters

|                             | Ships via                              | Merge → live                       |
| --------------------------- | -------------------------------------- | ---------------------------------- |
| `iam` (`portfolio-website`) | static site                            | minutes                            |
| `agent-rotom`               | Cloudflare (`functions/`, `.dev.vars`) | minutes                            |
| `jaksam`                    | Expo + app stores (`eas.json`)         | **days to weeks**, gated on review |

For the first two you can confirm the deploy yourself. For `jaksam` you cannot —
the release happens long after your session ends. Leave those `In Progress` with
a comment, and Gabe sets `Deployed` when he ships. Don't guess.

They differ in a second way that matters as much: **only `jaksam` reports to
Sentry** (`gabe-shin/jaksam-backup`). `iam` has no error reporting at all — its
#31 is open and `Blocked` — so every `iam` ticket takes the `No Sentry issue`
branch and waits on Hermes's cleanup pass. That is the honest state, not a
mistake to correct ticket by ticket.

## What is not built yet

As of 2026-09-15:

- **The board, fields, statuses and `board.sh` work.** The skill is synced into
  `iam` and `jaksam`; `agent-rotom` is pending.
- **Issues reach the board by hand, not from CI.** Auto-adding needs a PAT with
  both `repo` and `project` — the default `GITHUB_TOKEN` cannot write a
  user-owned Project — and a broad, long-lived credential parked in CI is a bad
  trade for saving one `board.sh add`. So **an issue filed from the web or a
  phone is not on the board until someone adds it**, and `board.sh next` cannot
  see it; sweep `gh issue list` against the board when picking up work. Don't
  re-propose the workflow.
- **Hermes has started sweeping.** Its first `jaksam` pass ran 2026-09-15 and
  moved three tickets `Deployed → Done`. Filing and Slack are still unwritten,
  so it reads finished work rather than finding new work.

What that pass declined to move is the clearest statement of the contract. It
left tickets at `Deployed` when the thread never recorded the ship, and when the
deployment comment named no Sentry issue in marker form — including ones
carrying a good `verify` block from the old convention. Both refusals are right:
it cannot resolve an issue for a ship it cannot see, and it will not guess which
issue you meant.

So **a ticket sits at `Deployed` until its deployment comment says how it went
live and which Sentry issue it closes** — or that it closes none.

Don't resolve a Sentry issue yourself to simulate the monitor. An issue resolved
with no fix deployed regresses noisily and teaches everyone to ignore the alert.
