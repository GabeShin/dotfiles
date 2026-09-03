# The whole picture

Read this when you need to know _why_ the board is shaped the way it is, or what
happens to a ticket after you let go of it. `SKILL.md` is the contract; this is
the context behind it.

## Three actors

**Hermes** is the eyes. A [Nous Research Hermes Agent](https://github.com/NousResearch/hermes-agent)
instance running on Gabe's always-on machine, with monitoring jobs over the
running software. It notices problems, files them, and — after a fix ships —
checks whether the problem actually stopped. It is the only actor that can
assert "this was verified", because it is the only one still watching after
everyone else has moved on.

**Gabe** decides. What gets built, what matters, what gets shipped. He files
tickets, sets priority, triages what Hermes finds, and performs the releases
that Hermes and agents cannot.

**You**, the coding agent, do the work. You take a ticket that has been agreed,
implement it, get it live, and hand it on. You are the only actor with the
diagnosis in context at the moment the fix ships — which is why writing the
verification contract is your job, not Hermes's. Hermes knows how to watch; only
you know what to watch for.

## Why one board across three repos

The board answers a question no single repo can: _of everything I could work on
tonight, across every side project, what matters most?_ Per-repo boards can't
compose into that, whereas one board filters down to a single repo trivially.
Views compose downward, not upward.

It is also the meeting point for three writers. Gabe files from a phone, Hermes
files from a monitor, an agent files something it noticed in passing — and all
three land in the same list, with `Source` recording which.

## The lifecycle

**Hermes finds something**

1. A monitoring job detects a problem and computes a **fingerprint** — a stable
   identity for _this specific problem_, not for the prose describing it.
2. It searches the board for that fingerprint. Found and open → bump
   `Occurrences` and `Last seen`, stay quiet. Found and **declined** → do
   nothing, ever. Not found → file a new ticket at `Todo`, `Source=hermes`.
3. It posts to Slack. High priority alerts immediately; the rest arrive in a
   digest, because a channel that pings on every finding gets muted, and a muted
   channel breaks the whole design at step one.

**Gabe picks it up**

4. He reads Slack, decides it's worth doing, sets `Priority`. Anything he wants
   you to know goes on the _issue_ — the ticket is the context surface, Slack is
   a view of it.

**You do the work**

5. Claim it: `In Progress`, before the first edit.
6. Implement, verify, commit. `Fixes #N` closes the issue on merge — but a
   closed issue is not a finished ticket here, because merged is not live.
7. Get it live and confirm that it is. Then ask whether there is a signal worth
   watching. If there is, set `Deployed` with a `verify` block naming the
   signal, the window, and what counts, and stop. If there isn't — most tickets
   — set `Done`, saying in the comment why nothing was monitorable.

**Hermes closes the loop**

8. It picks up `Deployed` items, registers a monitor from the `verify` block,
   and moves them to `In Monitor`. A `Deployed` item with **no** block is no
   longer the signal to close out — an agent with nothing to monitor now sets
   `Done` itself — so Hermes should treat a missing block as unintended, close
   the item out, and say that it had to guess. The exception is a release
   somebody else performed: the block will be in an earlier `In Progress`
   comment, not the `Deployed` one, so read the whole thread before concluding
   there is no contract.
9. After a clean window → `Done`. A recurrence → back to `Todo`, reopened, with
   a Slack alert. Cannot tell → says so, and does **not** claim verified.

Step 9 is the payoff. A ticket ends up holding the diagnosis, the fix, what the
fix was supposed to achieve, and whether it held — so when the thing recurs in
six months, the ticket answers what was already tried.

## Who may do what

|        | Files | Sets `Todo`-`Deployed` | Sets `In Monitor` | Sets `Done`         | Closes         | Reopens |
| ------ | ----- | ---------------------- | ----------------- | ------------------- | -------------- | ------- |
| Gabe   | yes   | yes                    | yes               | yes                 | yes            | yes     |
| You    | yes   | yes                    | **no**            | when nothing to monitor | via `Fixes #N` | no      |
| Hermes | yes   | `Todo` only            | yes               | yes                 | **never**      | yes     |

Hermes never closes: a bug in a monitoring job must not be able to hide real
work. Reopening is safe because it only ever surfaces something.

You never set `In Monitor`, because it asserts a monitor is running and you have
no way to know that; `board.sh` enforces it. `Done` is different, and used to be
guarded alongside it on the reasoning that it asserts a clean window passed.
That was wrong in one direction: `Done` also covers "there was never anything to
watch", which is the majority of tickets, and the agent at ship time is the
actor best placed to judge it — it is the one holding the diagnosis. Guarding it
meant finished work with no monitorable signal accumulated in `Deployed`
indefinitely, waiting on a transition nobody was coming to make. So `Done` reads
as **nothing is left to verify**, from either route.

## The invariants worth not breaking

- **One source of truth.** The board holds state; the issue holds detail; Slack
  is a view. When a second store appears — a `docs/todo.md`, a Hermes-local task
  list — they drift, and the board stops being believable.
- **Merged ≠ deployed ≠ verified.** Three distinct facts, three statuses. The
  built-in `Item closed → Done` workflow is deliberately **off**, because on this
  board it would be wrong.
- **`In Monitor` asserts a monitor exists.** That's why it is separate from
  `Deployed`. If Hermes is down, work visibly piles up in `Deployed` instead of
  sitting in a column that implies a watch nobody is performing. This is also
  why `Deployed` must stay reserved for things that genuinely have a signal:
  once no-monitor work goes straight to `Done`, the depth of the `Deployed`
  column becomes a real measure of unwatched risk. Parking a doc change there
  dilutes exactly the signal the column exists to give.
- **Dedup on fingerprints, never on prose.** Lexical search over descriptions
  will file the same bug twice under two phrasings. An exact-match token won't.
- **Declined means never again.** Without that, closing a false positive just
  invites Hermes to re-file it, and the loop poisons the board within a week.
- **Unmeasurable is not verified.** A low-traffic side project may never
  exercise a path in 72 hours. "No occurrences" on a dead path proves nothing,
  and reporting it as a pass makes the monitor decorative.

## The three repos differ in one way that matters

|                             | Ships via                              | Merge → live                       |
| --------------------------- | -------------------------------------- | ---------------------------------- |
| `iam` (`portfolio-website`) | static site                            | minutes                            |
| `agent-rotom`               | Cloudflare (`functions/`, `.dev.vars`) | minutes                            |
| `jaksam`                    | Expo + app stores (`eas.json`)         | **days to weeks**, gated on review |

For the first two you can usually confirm the deploy yourself. For `jaksam` you
cannot — the release happens long after your session ended. Leave those
`In Progress` with a comment saying it is merged and awaiting release, and Gabe
sets `Deployed` when he ships. Do not guess.

## What is not built yet

As of 2026-09-04, honestly:

- **The board, fields, statuses, and `board.sh` exist and work.**
- **The skill is synced into `iam` (portfolio-website); `jaksam` and
  `agent-rotom` are still pending.** One open ticket per repo covers it.

- **Issues reach the board by hand, not from CI.** The per-repo
  `project-add.yml` workflow was built for `iam` and then removed. The default
  `GITHUB_TOKEN` cannot write a user-owned Project, so auto-adding needs a PAT;
  and because these repos are private, that PAT needs `repo` as well as
  `project` — `board.sh` resolves an issue to its node id with `gh issue view`
  before it touches the board, so a project-only token fails with "Could not
  resolve to an Issue" and never even reaches the documented 403. A broad,
  long-lived credential parked in CI to save one `board.sh add` is a bad trade.
  Gabe's position: run it from a workstation where `gh` is already
  authenticated. Don't re-propose the workflow for `jaksam` or `agent-rotom`.

  This means **an issue filed on the web or from a phone is not on the board
  until someone adds it.** `board.sh next` only sees what was added, so a
  filed-but-unadded issue is invisible. Worth a sweep when picking up work:
  compare `gh issue list` against the board.
- **Nothing on the Hermes side is built.** No monitoring jobs, no fingerprinting,
  no Slack wiring, no verification. The design above is agreed; the
  implementation is not written.

So today, in practice: **`Deployed` is a queue for a consumer that does not
exist yet.** Anything that lands there stays there. That is the honest state of
the system rather than a defect — the column reads as "these shipped, nobody has
verified them", which is exactly true.

This is the reason an agent may now set `Done` itself. When the guard covered
both statuses, a ticket with nothing to monitor was indistinguishable on the
board from one waiting on a monitor, and both sat in `Deployed` forever. Sending
the first kind straight to `Done` keeps `Deployed` meaning something.

Whatever does accumulate there is Gabe's to sweep, and that sweep no longer
needs `BOARD_ALLOW_DOWNSTREAM=1` — `Deployed → Done` is an ordinary `board.sh
set` now. The override's only remaining user is Hermes, for `In Monitor`.

Don't write code that assumes Hermes is watching.
