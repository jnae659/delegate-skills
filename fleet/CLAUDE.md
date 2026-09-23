# Global instructions

## Delegation fleet — "delegate" triggers it, the agent picks the lane

- When I say "delegate" (e.g., "delegate this task", "delegate the auth refactor"), dispatch through
  the delegate fleet — the word is the instruction; do not implement inline instead.
- Unless I name a lane, choose it yourself by matching the work to the fleet map
  (`~/.config/delegate-skills/config.json`):
  - `feature` — everyday bounded implementation
  - `complex` — high-stakes: concurrency, migrations, security-adjacent, tricky cross-cutting changes
  - `tests` — writing or fixing tests
  - `fast` — quick mechanical edits (renames, small sweeps)
  - `e2e` — end-to-end coverage, browser-level (runs on `opencode/big-pickle`)

  If I name a lane, use exactly that one.
- **Lane truth = the config file only.** Memory notes and chat history describing lane→model
  mappings are historical — always re-read `~/.config/delegate-skills/config.json` before
  choosing a lane or announcing its model.
- Load the matching delegate skill (`opencode-delegate` for these lanes) and dispatch with
  `--lane <name>`. Follow the full loop: brief → dispatch → review diff → re-run gates → land.
- **ANTI-NESTING — every brief must end with this clause, verbatim:**
  "Do the work in this session. You may use your own `task` subagents ONLY as partitioned in the
  brief's <parallel_plan> (each stays inside its assigned files and never spawns further agents);
  beyond that, never dispatch other agents, CLI sessions, or relay scripts (relay.mjs); never
  write briefs for others to execute; never re-delegate any part of this task." An implementer
  that delegates beyond the plan is a bug, not initiative — watch for it in review (nested
  processes, brief files you did not write, `result.json` you did not create).
- **PARALLEL IMPLEMENTATION (feature/complex):** for non-trivial work that partitions cleanly
  into two disjoint file sets, the brief MUST include a `<parallel_plan>` block naming subagent A's
  files and subagent B's files (disjoint, no shared files; any shared interface written out in
  both halves) and instruct the implementer to run both `task` subagents simultaneously. Gates
  run ONCE, by the main session, after both subagents finish — never concurrently. No clean
  partition → single agent as usual; small tasks never parallelize. Review attributes the diff
  per partition.
- **ONE implementer per repo:** before any dispatch, check for a live relay against the same repo
  (`pgrep -f relay.mjs`); if one is running, never dispatch a second into that repo — queue it.
  Dispatches for DIFFERENT repos may run in parallel.
- **Every dispatch sets a watchdog:** `--timeout` is mandatory (default `2h`).
- **Tests auto-chain (conditional):** after the LAST dispatch of a task queue (or a one-off
  `feature`/`complex` dispatch) lands, queue a `tests` dispatch (glm-5.3-flash) to expand
  coverage ONLY when it earns its slot: the work was `complex`-lane or money-path, OR review
  judged the implementer's test coverage thin. Otherwise skip — and announce the call either
  way ("tests chain: firing — complex/money-path" or "tests chain: skipped — coverage solid").
  When it runs: full loop, announced, reviewed, gated, landed; defects it finds and does not
  fix → `B###` in the ledger. Fires ONCE per queue — never per phase.
- **E2E auto-chain (conditional):** at the same trigger point (auto-chained tests run lands, or
  the queue's `feature`/`complex` work lands when no tests chain ran), queue an `e2e` dispatch
  to add or extend E2E coverage ONLY when the landed diff touches the UI — `resources/js/`,
  package `Resources/js/`, blade views, page-rendering routes — or the task is a user-facing
  flow. Backend-only diffs skip it. Announce the call either way ("e2e chain: firing — UI
  changed" / "e2e chain: skipped — backend-only"). When it runs: full loop, announced, reviewed,
  gated, landed; scaffold a suite first if the repo has none.
- **E2E method — steer, then encode:** e2e briefs instruct the implementer to use the
  chrome-devtools MCP (when available and the app can be served) to drive the real UI and verify
  flows interactively — then write those verified flows as permanent automated tests
  (Playwright/Cypress per repo convention). MCP is for discovery; the suite is the deliverable.
- **E2E watchdog — kill-fast:** e2e dispatches run with `--timeout 45m`, never 2h. On timeout,
  resume (`--resume-last`) with a delta brief carrying the dead run's finalMessage — kill-fast +
  resume beats one long run.
- **E2E stop conditions:** every e2e brief carries a `<stop_conditions>` block — the same
  selector/flow failing 3× means stop iterating and report blockers + what was learned. Never
  burn the watchdog spiraling on a known-stuck problem.
- **E2E env-facts:** every e2e brief points at the repo's env-facts file (e.g.
  `plans/<pkg>/testing-env-facts.md`): read it first, append new discoveries (logins, setup
  steps, selectors, server quirks) at run end. Environment discovery is paid once, ever.
- **E2E watchable browser:** e2e runs headed locally with a single worker — one persistent,
  visible browser walking tests sequentially — video on, line reporter, retries 0. Stop
  conditions apply to spec authoring too: 3 failed attempts on the same spec → mark it blocked,
  report the failure as a finding, move on — never snapshot-archaeology past 3.
- **Chain boundaries:** the auto-chain follows `feature`/`complex` main work only — a dispatch
  explicitly aimed at `tests`, `fast`, or `e2e` triggers no further chaining. Stages run
  sequentially, never in parallel (one-implementer rule: queue each).
- **Batch for throughput:** when a plan or queue yields multiple phases with disjoint file
  areas, merge them into the minimum number of briefs (2–3 phases each) instead of one dispatch
  per phase — each brief is one review + one gate run + one commit. Inside a brief, have the
  implementer iterate with targeted tests (`--filter` / suite dirs); the orchestrator's
  full-gate HARD RULE applies per commit, unchanged.
- **QUEUE MODE:** when I hand over multiple tasks at once (or say "queue"), run them as one
  queue — plan related tasks together, batch into minimal dispatches, sequential within a repo,
  parallel across repos, chains fire once at queue end, wake me only for decisions or failures,
  and close with one consolidated report (lanes/models per dispatch + `BUGS.md: N open`).
- **Review the untouched list:** during review, check the brief's leave-untouched entries against
  `git status` — any covered file that changed is a violation, even if the code itself is correct.
- **Nested-dispatch tripwire:** `nestedDispatch: true` in a result means the implementer tried to
  re-delegate. Treat it exactly like a gates failure: do not land — rework the brief or re-dispatch.
- **HARD RULE — gates before landing:** never land (commit) delegated work without re-running the
  project's gates yourself in this session. The implementer's test output and pass/fail claims are
  not results. If a gate cannot run (missing dependency, wrong env, failing setup), stop and tell
  me instead of committing. No exceptions, never skipped for speed or convenience. Gate scope:
  intermediate landings of a batched queue run affected suites + pint/format on touched dirs +
  build once per batch; the FULL test suite runs before the queue's final landing (and always
  for one-off tasks). Scoped, never skipped.
- **HARD RULE — no destructive DB resets:** never run `php artisan migrate:fresh`,
  `migrate:refresh`, or `db:wipe` — in bash, via subagents, or in briefs; not even with
  `--env=testing`, not even to "fix" schema state. Forward-only `php artisan migrate` only.
  If schema state seems broken, stop and tell me. Every brief carries this ban.
- Always state which lane and model you chose when dispatching, and again in the final report —
  I always want to know which model did the work.
- Every final delegation report ends with a ledger line: `BUGS.md: N open` (and tasks remaining
  when relevant) — ledger state visible in chat without opening files.
- Without the word "delegate", implement directly yourself.

## Task sizing — the agent decides, then says so

Before implementing or dispatching, size the task yourself and announce the call:

- **Small** (few lines, one or two files, no risk): skip the ceremony — no plan file, no compact
  reminder. Just do it inline, or dispatch to `fast` if I said "delegate". Say
  "small task — doing it inline" so I know the sizing.
- **Non-trivial**: write the plan to a `.md` file first, remind me I can `/compact` before
  implementation, and on "delegate" build the brief from that plan file.

Sizing only controls the ceremony — "delegate" always dispatches regardless of size. If I say
"write the plan file anyway" or "just do it", that overrides the sizing.

## Documentation contract (non-trivial work)

Non-trivial tasks live in a folder `plans/<feature-name>/` (repo root `plans/`; create it if
absent; reuse the existing package folder when the work belongs to one). Over the task's life:

- **plan.md** — written at planning, BEFORE any dispatch: goal, current state, phases, decisions,
  verification approach. Updated when scope changes — never silently stale.
- **tasks.md** — T-numbered work items as checkbox lines (`- [ ]` → `- [x]` when done). Created
  at planning; updated as each phase lands. Briefs per dispatch go here too: `brief-phase-N.md`.
- **BUGS.md** — per the bug-ledger rule: append `B###` when a review/gate/campaign finds a defect
  not fixed in that run; flip `status: fixed in <hash>` in the fixing commit. Never created
  proactively.

Small tasks write nothing. The plan file is the source the brief is built from — no brief without
its plan entry.

## Bug ledger — BUGS.md (repo root)

Division of memory: `tasks.md` = planned work · `BUGS.md` = discovered defects · plan/spec `.md` =
decisions.

- **Filing:** when a review or gate run finds a defect that is NOT fixed in that same run, append
  the next `B###` entry to the repo's `BUGS.md` ledger — if the repo already has a `BUGS.md`
  anywhere (e.g. `plans/<package>/BUGS.md`), use that existing file; only otherwise create it at
  the repo root with a `# Bug ledger` header. Entry: title, checkbox status line
  (`- [ ] **open** · severity: <C/H/M/L or bug|critical> · area: <module>`), `found` (date +
  source), one-line detail. Report the new ID in chat.
  Defects fixed in the same run get no entry — no ceremony.
- **Closing:** when work lands that fixes `B00X`, tick its checkbox to
  `- [x] **fixed in <short-hash>**` in the SAME commit as the fix — the ledger update and the fix
  are atomic. Never leave the ledger stale.
- **Ledger files always use checkboxes** — `tasks.md` T-items and `BUGS.md` B-items are
  `- [ ]`/`- [x]` lines; no checkbox, no tracking.
- **Planning:** read open entries at planning time — they are candidate work like any other task
  and can be delegated to a lane.
