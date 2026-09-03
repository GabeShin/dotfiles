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
7. Get it live, confirm that it is, and set `Deployed` with a `verify` block
   naming the signal, the window, and what counts. If nothing is monitorable,
   set `Deployed` anyway and omit the block. Then stop.

**Hermes closes the loop**

8. It picks up `Deployed` items, registers a monitor from the `verify` block,
   and moves them to `In Monitor`. No block means nothing to watch: straight to
   `Done`.
9. After a clean window → `Done`. A recurrence → back to `Todo`, reopened, with
   a Slack alert. Cannot tell → says so, and does **not** claim verified.

Step 9 is the payoff. A ticket ends up holding the diagnosis, the fix, what the
fix was supposed to achieve, and whether it held — so when the thing recurs in
six months, the ticket answers what was already tried.

## Who may do what

|        | Files | Sets `Todo`-`Deployed` | Sets `In Monitor`/`Done` | Closes         | Reopens |
| ------ | ----- | ---------------------- | ------------------------ | -------------- | ------- |
| Gabe   | yes   | yes                    | yes                      | yes            | yes     |
| You    | yes   | yes                    | **no**                   | via `Fixes #N` | no      |
| Hermes | yes   | `Todo` only            | yes                      | **never**      | yes     |

Hermes never closes: a bug in a monitoring job must not be able to hide real
work. Reopening is safe because it only ever surfaces something. You never set
`In Monitor` or `Done` because both assert facts you cannot know — that a
monitor exists, and that a window passed clean. `board.sh` enforces that.

## The invariants worth not breaking

- **One source of truth.** The board holds state; the issue holds detail; Slack
  is a view. When a second store appears — a `docs/todo.md`, a Hermes-local task
  list — they drift, and the board stops being believable.
- **Merged ≠ deployed ≠ verified.** Three distinct facts, three statuses. The
  built-in `Item closed → Done` workflow is deliberately **off**, because on this
  board it would be wrong.
- **`In Monitor` asserts a monitor exists.** That's why it is separate from
  `Deployed`. If Hermes is down, work visibly piles up in `Deployed` instead of
  sitting in a column that implies a watch nobody is performing.
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

As of 2026-09-03, honestly:

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

So today, in practice: **`Deployed` is the end of the line.** Nothing moves items
out of it, and they will accumulate there. That is the honest state of the system
rather than a defect — it reads as "these shipped, nobody has verified them."
Gabe sweeps it by hand with `BOARD_ALLOW_DOWNSTREAM=1` until Hermes exists.

Don't write code that assumes Hermes is watching.
