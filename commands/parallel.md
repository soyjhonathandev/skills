---
description: Run the tracks of an approved multi-track contract (from /team) at the same time, one worktree, branch, port and test database per track, then review and integrate them.
---

# /parallel: parallel tracks

> **You (Claude Code) are the orchestrator. The developer is the engineering manager.** This flow runs the
> tracks of one approved contract at the same time, each in its own worktree and branch, with its own port and
> test database, then integrates them. Ask ONE question at a time. Every block marked "Print:" is literal.
>
> **You are the only writer of the session status and log.** Tracks never write them: background agents return
> a `plan-update` block to you; developer-steered track sessions hand you the same block.
>
> Run this flow as the main agent of a session in the repo, never as a subagent: a Claude Code subagent cannot
> spawn subagents, and this flow spawns implementers and reviewers. Agent mode uses `isolation: "worktree"`,
> which creates a worktree of the repository this session runs in, so it works here and only here.

Session files live in `.claude/sessions/<slug>/` (`contract.md`, `status.json`, `log.jsonl`), written by
`/team`. Their full format, the hash commands, the event types and the append protocol are in the `/team`
command, section "Session files". Hash check, used below:

```bash
{ command -v sha256sum >/dev/null && sha256sum "$CONTRACT" || shasum -a 256 "$CONTRACT"; } | awk '{print $1}'
head -n 1 "$LOG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["payload"]["contract_sha256"])'
```

Every log append is a heredoc with a single-quoted delimiter (`cat >> "$LOG" <<'EOF'`), one event per line.
Every status.json write is atomic: write `status.json.tmp`, then `mv` it over the target.

## Safety rules

The `parallel-sessions` and `worktree-and-branches` skills hold the full rules. In short:

- Concurrent tracks have disjoint `files_to_modify`. Each shared file (lockfile, `package.json`, routing
  modules, root reducers, the root app module, the server app entry and router index, shared DTOs) belongs to
  exactly one track, named in `shared_files_owner`. An overlap is a BLOCK, never a warning.
- One writer per worktree. Reviewers never edit.
- One port per worktree. One test database per worktree: `test_<slug>_<track>`.
- Destructive or admin endpoints (resets, reversals, bulk deletes) only against a local or disposable test
  tenant.
- Nothing is pushed and nothing is merged without the developer asking for it in this session.

---

## Step 0: Banner

Print:

```
 Parallel tracks
 Each track is its own worktree, branch, port and test database. Cost grows with the number of tracks;
 parallelism buys wall-clock time, not token savings.
```

---

## Step 1: The contract

### 1.1 Find the source

Glob `.claude/sessions/*/status.json`, newest by mtime. If its contract has phases with a `track` and its
status is `draft` or `executing`, that is the source. Else print:

```
/parallel needs an approved multi-track contract.

[0] Run /team to design one (recommended)
```

and stop.

### 1.2 Disjointness check (before anything is created)

```bash
awk '/^- \*\*track:\*\*/{tr=$3} /^- \*\*files_to_modify:\*\*/{f=1;next} /^- \*\*/{f=0} f&&/^  - /{print tr"\t"$2}' "$CONTRACT" | sort -u | awk -F'\t' '{n[$2]++; t[$2]=t[$2]" "$1} END{for(p in n) if(n[p]>1) print "OVERLAP " p ":" t[p]}'
```

- No output: the tracks are disjoint.
- Any `OVERLAP` line between tracks that can run at the same time (neither depends on the other, directly or
  through a chain): **BLOCK**. Print the lines and stop: the plan must change (new contract, new slug). The
  file goes to one track, and the others request their change through it.
- An overlap between tracks in one `depends_on` chain is allowed: they never run together, and the later one
  branches after the earlier one merges.

Then check shared files: every path listed in `shared_files_owner` appears only in its owner's
`files_to_modify`. Also scan the track file lists for the usual shared files
(`grep -E '(^|/)(package(-lock)?\.json|app\.module\.ts|[^/]*routing\.module\.ts)$'`, plus the repo's own shared
files such as the router index, root reducers and the shared DTO folder, as `AGENTS.md` or `CLAUDE.md` lists
them). A shared file in a track that is not its named owner is a BLOCK.

### 1.3 Validate the session

Status not terminal (`done`, `aborted`, `drift_blocked` stop the flow). Contract present (else
`BLOCK (contract missing)`). Log line 1 valid `contract_approved` (else `BLOCK (log empty)` or
`BLOCK (log corrupt)`). Hash matches (else `BLOCK (contract drift)`: set `drift_blocked`, append `verdict` and
`status_changed`, stop). If HEAD moved since `planned_against_sha`, warn with both SHAs; informational only.

This session is the orchestrator and runs in the feature's integration worktree, on branch `<prefix>/<slug>`,
never in the primary checkout or on trunk. If it is not, print the commands and stop:

```
git worktree add ../<repo>-<slug> -b <prefix>/<slug> <trunk>
cd ../<repo>-<slug> && <clean-install command from AGENTS.md or CLAUDE.md>
claude -n <repo>-<slug>
```

The branch prefix comes from the `worktree-and-branches` skill: `git config branch.prefix`, else your existing
branches, else ask.

---

## Step 2: Allocate

For each track, in contract order:

- **branch:** `<prefix>/<slug>-<track>`
- **worktree:** `../<repo>-<slug>-<track>` (session mode) or the isolated worktree the harness creates (agent
  mode, recorded when the agent reports it)
- **session name:** `<repo>-<slug>-<track>` (session mode). Names must be unique: Claude Code accepts duplicate
  names silently and then routes messages to the latest.
- **port:** start from the dev server port in `AGENTS.md` or `CLAUDE.md` plus 1, and take the next free one:
  `lsof -nP -iTCP:<port> -sTCP:LISTEN` prints nothing when the port is free. Skip ports already given to other
  tracks of this or any open session. If the repo does not document its dev server port, ask.
- **test database:** `test_<slug>_<track>`, `-` turned into `_`, at most 63 bytes, on a local database only.
  The track passes it through the test database env var the repo documents, set in its own shell, never in a
  committed file.
- **mode:** `agent` for a well-specified track with few decision points; `session` for a track the developer
  wants to steer (by default for `e2e`). Recommend one per track and say why.
- **implementer:** `expert-developer`; `test-engineer` for an `e2e` track.

Print:

```
+----- TRACK DISPATCH ---------------------------------------------------------+
| track     mode     branch                     port   test db           deps  |
| api       agent    <prefix>/<slug>-api        <p>    test_<slug>_api   none  |
| app       session  <prefix>/<slug>-app        <p>    test_<slug>_app   none  |
| e2e       agent    <prefix>/<slug>-e2e        <p>    test_<slug>_e2e   api   |
+------------------------------------------------------------------------------+

Running now: <tracks with no pending dependency>. Waiting: <tracks with dependencies>.
Each running track costs about one full session; a track in agent mode runs unattended.

[0] Approve and dispatch (also approves the clean install in each new track worktree)
[1] Change a track's mode
[2] Cancel
```

Wait.

---

## Step 3: Dispatch

If status is `draft`, set it to `executing` and append `status_changed`. Set `current_phase_id: "integration"`
only when Step 5 starts; until then per-track progress lives in `tracks`.

For each track whose dependencies are met (none, or all merged into the integration branch):

1. **Base.** `base_sha` = `planned_against_sha` for a track with no dependency; the integration branch HEAD
   for a track whose dependencies just merged.
2. **Agent mode.**
   - Create the branch only: `git branch <branch> <base_sha>`. Do not add a worktree for it: a branch can be
     checked out in one worktree only, and the agent gets its own.
   - Spawn the implementer with the Agent tool, `isolation: "worktree"`, running in the background. The prompt
     starts with:

     ```
     Contract file: <CONTRACT>
     Status file: <STATUS>
     Log file: <LOG>
     Read ONLY the contract file (plus log line 1 for the hash). Do not read or write status or log.
     Phase to implement: <phase id>
     Track: <track id>
     First command: git switch <branch>    (stop and report if it fails)
     Second command: the clean-install command from AGENTS.md or CLAUDE.md (approved with this
       dispatch; stop and report if the lockfile changes)
     Port: <port>    Test database: <test db>
     ```

     Then the phase block verbatim, the other concurrent tracks' `files_to_modify` (off limits), the shared
     files this track does not own (off limits), and: commit on the track branch following the
     `commit-creation` skill, never push, never merge, report `worktree` (`pwd`) and `head_sha` in the
     `plan-update` block. Decision points come back to you; relay them to the developer.
3. **Session mode.**
   - `git worktree add ../<repo>-<slug>-<track> -b <branch> <base_sha>`
   - Install step, approved with the dispatch in Step 2: run the clean-install command inside the new worktree
     (`cd ../<repo>-<slug>-<track> && <clean-install command>`). A changed lockfile stops that track and is
     reported.
   - Print for the developer:

     ```
     Track <id>: open a new terminal and run
       cd ../<repo>-<slug>-<track> && claude -n <repo>-<slug>-<track>
     then paste:
       Act as the expert-developer agent for one track.
       Contract file: <CONTRACT>
       Status file: <STATUS>
       Log file: <LOG>
       Read ONLY the contract file (plus log line 1 for the hash). Do not read or write status or log.
       Phase to implement: <phase id>    Track: <track id>
       Port: <port>    Test database: <test db>
       Off limits: <other tracks' files and the shared files this track does not own>
       Commit on this branch, never push or merge, and end with the plan-update block.
       Orchestrator session: <this session's name>
     When it finishes, it sends (or you paste here) its plan-update block.
     ```

4. Record the track: append `track_dispatched` (with `base_sha` in the payload) and `phase_started` (with
   `track`), and add the `tracks.<id>` entry to status:

   ```json
   "tracks": {
     "app": {
       "phase_id": "p2", "mode": "agent", "branch": "<prefix>/<slug>-app", "worktree": "<absolute path>",
       "session_name": null, "port": 4201, "test_db": "test_<slug>_app", "depends_on": [],
       "base_sha": "<sha>", "status": "running", "head_sha": null
     }
   }
   ```

   Track status is `pending | running | review | pass | blocked | merged | aborted`.

Tracks with unmet dependencies stay `pending`.

---

## Step 4: As tracks finish

A background agent's completion notification, a message from a track session, or a pasted block marks a track
as finished. Never predict a result that has not arrived; if the developer asks, say which tracks are still
running.

For each finished track:

1. **Parse** its `plan-update` block. Check the branch moved and the work is committed:
   `git rev-parse <branch>` equals `head_sha`, and `git -C <worktree> status --short` is empty (uncommitted
   work is invisible to the reviewer: ask the track to commit).
2. **Review.** Spawn plan-reviewer:

   ```
   Contract file: <CONTRACT>
   Status file: <STATUS>
   Log file: <LOG>
   Audit scope: contract + diff + contract_sha256 from log line 1. Do not read status.json or log lines after line 1.
   Phase under review: <phase id>
   Track: <track id>
   Diff: git diff <base_sha>..<branch>
   Concurrent tracks and their files_to_modify: <list>
   ```

3. **Write events** with `track` in every payload: `phase_completed`, one `decision`, `problem` or `opinion`
   per block item, one `verdict` per review. Update `tracks.<id>` (`status`, `head_sha`, `worktree`)
   atomically.
4. **Verdict:**
   - `PASS` or `PASS WITH NOTES` (notes accepted or fixed): track `pass`.
   - `BLOCK`: `[0] Fix and re-review [1] Show the review [2] Override (not allowed for a track overlap)`. The
     fix goes to the same track: in agent mode, continue the same agent (SendMessage to its id) or spawn a new
     implementer without isolation, told to work only inside the recorded worktree; in session mode, send or
     print the must-fix list for the track session.
   - `BLOCK (contract drift)`: stop every track (TaskStop for running agents, a message to each track
     session), set `drift_blocked`, plan again.
5. **Dependents.** When a passed track has dependents, offer:
   `[0] Merge <track> into <prefix>/<slug> now so <dependents> can start (recommended) [1] Wait for the rest`.
   A merge follows Step 5.2 for that one track, then Step 3 for the dependents.
6. **Board.** After every change print:

   ```
   track   mode     branch                  port   status    verdict
   api     agent    <prefix>/<slug>-api     <p>    pass      PASS
   app     session  <prefix>/<slug>-app     <p>    running   -
   e2e     agent    <prefix>/<slug>-e2e     <p>    pending   -
   ```

When every track is `pass` (or `merged`), go to Step 5.

---

## Step 5: Integration

Set `current_phase_id: "integration"` and append `phase_started` with `phase_id: "integration"`.

### 5.1 Combined review

Collect the combined diff: `git diff <base_sha>..<branch>` for every track not yet merged, plus
`git diff <planned_against_sha>..HEAD` for what already merged. Spawn **api-contract-reviewer** and
**architecture-reviewer** as an Agent Team in parallel, each with the three directive lines,
`Phase under review: integration`, the combined diff and the contract's API Contract block. When the
contract's `planning_mode` or constraints involve money or tenant scoping, add security-reviewer and
domain-expert. Reviewers are read-only.

Print:

```
+----- INTEGRATION SYNTHESIS -----------------------+
|  Consensus:                                        |
|    - <finding> (flagged by: agent, agent)          |
|  Conflicts:                                        |
|    - <agent>: <position> / <agent>: <position>     |
|  Contract mismatches between tracks:               |
|    - <endpoint or field>: <track> vs <track>       |
|  Surprises:                                        |
|    - <finding>                                     |
+----------------------------------------------------+

[0] Accept and plan the merge
[1] Show the findings in detail
[2] Send fixes to a track (back to Step 4 for it)
```

Log each reviewer's verdict with `phase_id: "integration"`.

### 5.2 Merge-order plan

Order: `migration`, then `api`, then the client tracks (`app` and any other), then `e2e`, then `docs`,
adjusted so every track follows the tracks it depends on. Print:

```
Merge order into <prefix>/<slug> (run in this worktree):
  1. git merge --no-ff <prefix>/<slug>-migration
  2. git merge --no-ff <prefix>/<slug>-api
  3. git merge --no-ff <prefix>/<slug>-app
  4. git merge --no-ff <prefix>/<slug>-e2e

[0] I'll run them
[1] Run them for me now
```

Merging is allowed only because the developer asks for it here. After each merge append `track_merged` and
set the track to `merged`. A conflict means a shared-file rule was broken: stop, show the conflicted files, and
let the developer decide. Never resolve a conflict silently.

### 5.3 Cross-phase review

1. Run the contract's `validation_gate` on the integration branch. If the contract has an `e2e` track, run its
   scenario on this worktree's own port and test database.
2. Spawn plan-reviewer for the cross-phase review: the three lines, `Cross-phase review`, and
   `git diff <planned_against_sha>..HEAD`. Append its verdict with `phase_id: "cross-phase"`.

### 5.4 Close

```
Parallel run complete: <slug>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tracks:              <id: merged> per track
Integration review:  <verdicts>
Gates:               <command: result>
Cross-phase review:  <verdict>

[0] Show the full diff
[1] Fix what is left
[2] Close
```

On close: status `done`, `current_phase_id: null`, `current_phase_index: null`, append `status_changed` with
reason `cross_phase_pass`. Then print the cleanup for the developer to run:

```
git worktree remove ../<repo>-<slug>-<track>     (one per session-mode track; agent worktrees per the harness)
git branch -d <prefix>/<slug>-<track>            (after the integration branch is merged upstream)
Stop the dev servers on ports <list>. Drop the local test databases test_<slug>_*.
```

Push and PR only when the developer asks, following the `pr-creation` skill.
