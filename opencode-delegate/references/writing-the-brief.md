# Writing the brief

A brief is the entire task as OpenCode will see it. OpenCode runs in a fresh session with **no memory of
your conversation, no access to your prior notes, and no shared context** — only the text you send and
whatever it can read from the working tree (including the repo's own `AGENTS.md`, which it picks up
automatically). If a constraint isn't in the brief or discoverable in the repo, it doesn't exist for
OpenCode. The single most common failure is a brief that assumes context OpenCode doesn't have.

## Match the model to the brief

OpenCode has no default model, so every fresh dispatch names one with `--model provider/model`. Which
model is a two-owner decision: the **human** owns which models are allowed to run; **you, the
orchestrator**, pick one of them to fit the task in front of you.

- **The allowed set is the human's to state.** `opencode models` lists a few hundred models, but most
  bill per token (OpenRouter and the like) and the CLI does not mark which are the human's
  subscriptions. So they name their usable models — ideally once, in the target repo's `AGENTS.md` or
  their `CLAUDE.md` (e.g. `opencode-go/…`, `zai-coding-plan/…`, `minimax-coding-plan/…`). If they
  haven't, ask before dispatching rather than guessing a model and risking a metered bill.
- **Read the task's difficulty off the brief you just wrote, and match within that set.** A mechanical,
  well-bounded brief — a rename sweep, a `moment`→`date-fns` migration, a dead-code removal — is safe on
  a cheap, fast model. A brief whose risk lives in judgment — a concurrency fix, a money or auth path,
  an ambiguous spec — wants a strong one, because the sweep's failure modes (plausible-but-wrong logic,
  swallowed errors) are exactly what a weaker model produces more of.
- **A resumed run keeps the first run's model.** `--resume-last` / `--session` don't take `--model`; the
  session already has one. Send only the delta brief.

## The shape that works

OpenCode responds well to compact, block-structured prompts with XML tags rather than long prose. State
the task, what "done" looks like, how to behave by default, and the few constraints that actually
matter. Add a block only when the task needs it — don't ship empty ceremony.

```xml
<task>
One or two sentences: the concrete job and where it lives. Then the specifics — current state, what to
change, and explicitly what to leave untouched. The "leave untouched" list is what keeps OpenCode from
wandering into unrelated refactors.
</task>

<verification_loop>
Implement → targeted tests → format changed files → finish. Specifically:
  <the project's real test command, scoped to the tests covering the touched code (--filter / test dir)>
  <the project's real formatter, on the changed files only>
Run the targeted tests to green and fix what they surface. Do NOT run the full test suite or the
build — the orchestrator runs those once, in parallel, at its gate. Don't re-run suites unrelated
to your change. Confirm the working tree shows only the intended changes afterward.
</verification_loop>

<action_safety>
Keep changes scoped to the task. No unrelated refactors, renames, or cleanup unless required for
correctness. Do NOT run git add or git commit — the orchestrator commits after reviewing. Leave the
work uncommitted in the working tree. Never run php artisan migrate:fresh, migrate:refresh, or
db:wipe — forward-only `php artisan migrate` only; if schema seems broken, report instead of
resetting.
</action_safety>

<no_nesting>
Do the work in this session. You may use your own `task` subagents ONLY as partitioned in the
brief's <parallel_plan> block when one is present (each subagent stays inside its assigned files
and never spawns further agents); beyond that, never dispatch other agents, CLI sessions, or
relay scripts (relay.mjs); never write briefs for others to execute; never re-delegate any part
of this task.
</no_nesting>

<parallel_plan>
Optional, only when the work splits into two disjoint file sets: name subagent A's files and
subagent B's files (no overlap; write any shared interface out in both halves), instruct that
both `task` subagents run simultaneously, and that gates run ONCE from the main session after
both finish.
</parallel_plan>

<structured_output_contract>
End with a report in this exact shape:
  1. What changed and why
  2. Files touched
  3. Gate outcomes (paste the test/lint counts)
  4. Anything you deviated on, left open, or want a decision on
</structured_output_contract>
```

That five-block skeleton covers most implementation tasks. The `<no_nesting>` block is mandatory on
**every** brief — an implementer that re-delegates is a bug, not initiative, and the relay's
`nestedDispatch` tripwire flags attempts even when a permission layer blocks them. Reach for the
extra blocks when the task profile calls for them:

- **Debugging / open-ended fixes** — add `<completeness_contract>` (resolve fully, don't stop at the
  first plausible fix) and `<missing_context_gating>` (don't guess missing repo facts; find them or
  state what's unknown).
- **Review / diagnosis (read-only)** — add `<grounding_rules>` (ground every claim in evidence; label
  inferences) and dispatch with `--read-only` so OpenCode runs as the `plan` agent and can't edit.
- **Research / recommendations** — add `<research_mode>` (separate observed facts, inferences, open
  questions).

## Always ask for the report explicitly

The relay assembles OpenCode's final message from the text it emits when it stops. If the agent finishes
a task purely through tool calls and stops without a closing summary, `finalMessage` comes back empty —
not a relay defect, just nothing said. The `<structured_output_contract>` block is what guarantees a
report you can read: it tells OpenCode to end with a written summary, so the result file carries one.

## Discover the real gates — don't hardcode

`<verification_loop>` is only useful if it names the project's *actual* commands. Read the repo's
`AGENTS.md` / `CLAUDE.md` / `Makefile` / `package.json` first and copy the real ones in (`make test`,
`npm run lint`, `cargo test`, `pytest -q`, whatever it is). A brief that says "run the tests" without
naming them gets you an OpenCode that guesses — or skips.

## Split the gates: targeted for the implementer, full for the orchestrator

The implementer's loop is **implement → targeted tests → format changed files → finish**. Scope
its test command to the code it touches (a `--filter`, a test directory) and its formatter to the
changed files. Never ask it to run the full suite or the build: profiling showed repeated full and
sequential suite runs inside the implementer dominated wall time (91 of 114 minutes on one run),
and the orchestrator re-runs everything anyway. The **orchestrator's gate** runs the full suite
once, with the repo's parallel runner (e.g. `php artisan test --parallel --processes=8`), plus
build/typecheck, then reviews the diff and commits.

## Fast test infrastructure — check for it, use it, carry it into worktrees

Two pieces of test infrastructure make both gates cheap. Check whether the repo has them (its
`AGENTS.md`/`CLAUDE.md`, `phpunit.xml`, `scripts/`) and name them in the brief; if it lacks them
on a large suite, suggest adding them to the human rather than living with slow gates.

1. **Parallel test runner** (e.g. ParaTest via `php artisan test --parallel --processes=8`;
   `pytest -n auto`; `jest --maxWorkers`). It splits the suite across workers, each with its own
   database (Laravel: `<db>_test_1` … `_8`, auto-created) — same tests, same pass/fail, faster
   (≈1.65× on a ~900-test Laravel suite). Workers can run out of memory; set the limit in the
   runner config (Laravel: `<ini name="memory_limit" value="1G"/>` in `phpunit.xml`) instead of
   per command. This is the **orchestrator's** full-suite command. Parallel suites are heavy on
   the database server — don't run more than about two at once across worktrees.
2. **Test schema dump** (Laravel: `database/schema/mysql-schema.sql`). Database-refreshing tests
   load the finished schema in one step, and only migrations newer than the dump run on top,
   instead of replaying hundreds of migration files per process. If some migrations seed rows
   (permissions, lookup tables), the dump must keep those rows — a plain `schema:dump` only keeps
   the `migrations` table, so use the repo's dump script if it has one (e.g.
   `scripts/dump_test_schema.sh`). Regenerate it after adding migrations; tell the implementer to
   do so in any brief that adds migrations.

When the implementer works in a git worktree, make sure the worktree carries everything the test
runner relies on that may be untracked or newer than the branch point — above all the schema
dump. Without it, every database-refreshing test replays all migrations and a three-file test
directory can take 10–20 minutes.

## Honor the repo's conventions

OpenCode reads the repo's `AGENTS.md` automatically, so house rules there (style, forbidden patterns,
commit conventions) already apply. If the project forbids certain things in code — say, spec/ticket IDs
in comments, process language like "MVP"/"for now"/"phase N", or specific test conventions, whatever the
repo's own conventions ban — restate the load-bearing ones in the brief too, because OpenCode's
compliance is only as reliable as what's in front of it.

## One task per brief

Keep each brief to a single, bounded job. "Review this, fix what you find, update the docs, and suggest
a roadmap" produces a muddled run; split it into separate dispatches. One brief → one OpenCode run →
one commit keeps review and rollback clean, and lets a later task assume the earlier one landed.

## Premises freeze at dispatch

The implementer starts from the brief's facts and there is no steering channel mid-run. Audit the
fact block before sending — ownership, target branch, constraints, anything a judgment call rests
on. If a premise turns out wrong while the run is live, stop the run and re-dispatch a corrected
brief rather than discounting the output afterward; for a write-capable run, inspect the working
tree and reconcile any partial or premise-contaminated edits — keep or revert them — before the
re-dispatch.

## A worked example

```xml
<task>
In the payments service at services/billing/, the refund path double-charges when a refund is retried
after a network timeout (the idempotency key isn't checked before re-submitting). Make the refund
submission idempotent: check for an existing refund by idempotency key before creating a new one.
Touch only services/billing/refund.py and its tests. Leave the charge path, the API routes, and the
data models untouched.
</task>

<verification_loop>
Run and make green before finishing (targeted only — the orchestrator runs the full suite):
  pytest tests/billing/test_refund.py -q
  ruff format services/billing/refund.py tests/billing/test_refund.py
Confirm git status shows only refund.py and its test file changed.
</verification_loop>

<action_safety>
Scope strictly to the refund idempotency fix. No unrelated refactors. Do NOT git add or commit; leave
changes in the working tree for review. Never run php artisan migrate:fresh, migrate:refresh, or
db:wipe — forward-only migrate only; report broken schema instead of resetting.
</action_safety>

<no_nesting>
Do the work in this session. You may use your own `task` subagents ONLY as partitioned in the
brief's <parallel_plan> block when one is present (each subagent stays inside its assigned files
and never spawns further agents); beyond that, never dispatch other agents, CLI sessions, or
relay scripts (relay.mjs); never write briefs for others to execute; never re-delegate any part
of this task.
</no_nesting>

<structured_output_contract>
Report: (1) the root cause and your fix, (2) files touched, (3) pytest + ruff outcomes with counts,
(4) anything you left open or want decided.
</structured_output_contract>
```

Send this with `relay.mjs` (see [dispatch-and-poll.md](dispatch-and-poll.md)); review the result and
commit it yourself (see [review-and-land.md](review-and-land.md)).
