---
name: parallel-sessions
description: Enforceable rules for parallel work with Claude Code: unique session names, track sizing and modes, disjoint files with one owner per shared file, one writer per worktree, one port and one test database per worktree, destructive endpoints only on test tenants, with reviewer checks. Load before planning or running more than one track at once, and in /parallel.
---

# Skill: Parallel Sessions

> Parallel work is safe or it does not start. Each track has its own branch, worktree, session name, port and
> test database, and a file set no other concurrent track touches. Shared files belong to one track. One writer
> per worktree, one writer per file of session state. The checks below are what the orchestrator and the
> `plan-reviewer` agent run before launch and before merge.

## When this applies

Any plan with more than one track or task running at the same time; `/team` when it designs tracks;
`/parallel`. Branch and worktree naming is in the `worktree-and-branches` skill.

## Rules

1. **A session's name is its address, and it is unique.** Name a code session `<repo>-<slug>`, plus
   `-<track>` when two tracks share a repo. The worktree carries the same label (`../<repo>-<slug>`); a
   track's branch is `<prefix>/<slug>-<track>`. Start with `claude -n <name>` from inside the worktree. Claude
   Code accepts duplicate names silently and then routes to the latest, so check uniqueness before printing a
   launch command.
   - ✅ Do: `cd ../shop-api-refund-reason && claude -n shop-api-refund-reason`
   - ❌ Don't: `claude -n api` in two terminals, or start a session from the parent folder of all repos.

2. **One session per worktree, one worktree per branch.** Never two sessions, or a session and a headless
   agent track, writing the same worktree.
   - ✅ Do: a second opinion runs as a read-only reviewer that returns findings.
   - ❌ Don't: open a second session in `../shop-app-refund-reason` "just to fix the styles".

3. **Size a track to one repo, one disjoint file set, one PR.** Track kinds are `api`, `app` (a client),
   `e2e`, `migration`, `docs`, with a kebab suffix when a repo has several (`app-admin`). If a track needs two
   repos it is two tracks; if its PR would not be reviewed in one sitting, split it.
   - ✅ Do: a refund reason feature as `api` + `app` + `e2e`.
   - ❌ Don't: one "full-stack" track editing the API and the client app in one session.

4. **Pick the mode per track.** `agent` (a background implementer in its own worktree, ends with a
   `plan-update` block) for well-specified tracks; `session` (a named terminal the developer steers) for
   tracks with many decision points, and by default for `e2e`; `team` (Agent Team, read-only, about 3 to 4
   times the cost) for research, design and review. Inside a repo session, `/parallel` spawns agent tracks
   with the Agent tool and `isolation: "worktree"`. From a session that does not run in the target repo, never
   do that: `isolation: "worktree"` creates a worktree of the session's own repo, and a subagent cannot spawn
   the `plan-reviewer`. Create the worktree with `git -C <repo> worktree add`, run the install step, and launch
   a headless session inside it instead, output redirected to a log file.
   - ✅ Do: `cd ../shop-api-<slug> && claude -p -n shop-api-<slug> --permission-mode acceptEdits "<kickoff prompt>" > .claude/sessions/agent-run.log 2>&1`
   - ❌ Don't: spawn a code track for another repo with the Agent tool.
   - ✅ Do: `api` as `agent`, `app` as `session` because UI copy needs decisions.
   - ❌ Don't: a `team` that edits code.

5. **Disjoint files; every shared file has one owner.** Lockfiles, `package.json`, routing modules, root
   reducers, the root app module, the server app entry or router index, and shared DTOs belong to exactly one
   track, named in the contract's `shared_files_owner`. Other tracks request changes through it as a recorded
   decision. Overlap is a planning error, and `plan-reviewer` BLOCKs it.
   - ✅ Do: the `app` track owns the root module; the `e2e` track asks it for a route.
   - ❌ Don't: two tracks both adding a dependency to `package.json`.

6. **The client never waits for the API.** The `app` track codes against the pinned API contract with HTTP
   mocks and fixtures. Merge order: `migration`, `api`, then the client tracks, then `e2e`, then `docs`.
   - ✅ Do: start `api` and `app` at the same moment.
   - ❌ Don't: hold the `app` track until the API PR merges.

7. **One writer per worktree and per file of state.** Reviewers never edit. Subagents and track sessions
   return YAML; the orchestrator writes status and log, status always whole-file to `.tmp` then `mv`, the log
   append-only.
   - ✅ Do: fold each track's `plan-update` block into the session's `status.json` and `log.jsonl` in the
     orchestrator.
   - ❌ Don't: let a track session edit the status file.

8. **One port per worktree.** The primary checkout keeps the base dev server port. Each worktree gets the
   lowest free port above it, recorded in its track entry (`port`) before anything starts.
   - ✅ Do: `ng serve --port <port from the track>` (or the stack's equivalent flag)
   - ❌ Don't: run two dev servers on the default port and let the second one pick at random.

9. **One test database per worktree.** `test_<slug>_<track>` in the track's `test_db`, seeded from fictitious
   fixtures, dropped when the track is `merged` or `aborted`.
   - ✅ Do: `test_refund_reason_api` and `test_refund_reason_e2e` (`-` becomes `_`).
   - ❌ Don't: point the API tests and the e2e run at the same database.

10. **Destructive endpoints only on a local or disposable test tenant.** Resets, reversals, bulk deletes and
    similar admin operations never run against staging, production or any tenant with real data (the
    `customer-data-protection` skill).
    - ✅ Do: reset inventory on a demo tenant in the worktree's local stack.
    - ❌ Don't: call a reset endpoint on a shared staging tenant between e2e runs.

11. **State the cost.** Parallel tracks buy wall-clock time, not savings. An Agent Team costs about 3 to 4
    times one session.
    - ✅ Do: "3 tracks in parallel: done sooner, about the same tokens as running them in a row."
    - ❌ Don't: "parallel tracks will be cheaper."

## Reviewer checks

Run from the orchestrator's worktree. `S` is the session's `status.json`, `C` its `contract.md`.

```bash
S=.claude/sessions/<slug>/status.json; C=.claude/sessions/<slug>/contract.md
open='.tracks // {} | to_entries[] | .value | select(.status != "merged" and .status != "aborted")'
# Duplicate port, test_db, session_name or worktree across open tracks of every session: must print nothing
for k in port test_db session_name worktree; do jq -r "$open | .$k // empty" .claude/sessions/*/status.json | sort | uniq -d; done
# Ports already taken by another process before launch
for p in $(jq -r "$open | .port" "$S"); do lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null && echo "busy $p"; done
# Planned overlap: a path in two tracks' files_to_modify
awk '/^- \*\*track:\*\*/{tr=$3} /^- \*\*files_to_modify:\*\*/{f=1;next} /^- \*\*/{f=0} f&&/^  - /{print tr"\t"$2}' "$C" \
  | sort -u | awk -F'\t' '{n[$2]++; t[$2]=t[$2]" "$1} END{for(p in n) if(n[p]>1) print "OVERLAP " p ":" t[p]}'
# Actual overlap: a file changed on two open track branches
jq -r "$open | \"\(.base_sha) \(.branch)\"" "$S" \
  | while read -r base br; do git diff --name-only "$base...$br"; done | sort | uniq -d
# Each track's worktree really holds its branch
jq -r "$open | select(.worktree != null) | \"\(.worktree) \(.branch)\"" "$S" \
  | while read -r wt br; do git worktree list --porcelain | grep -A2 -xF "worktree $wt" \
      | grep -qxF "branch refs/heads/$br" || echo "MISMATCH $wt $br"; done
```

## Checklist (for reviewers)

- [ ] Every check above prints nothing.
- [ ] Every track has `mode`, `port`, `test_db` and, in session mode, a unique `session_name` before launch.
- [ ] Each shared file appears in exactly one track's `files_to_modify`, matching `shared_files_owner`.
- [ ] The `app` track has mocks and fixtures for the pinned contract and did not wait for the API.
- [ ] No reviewer or subagent wrote to a worktree, and no track session wrote the status or log file.
- [ ] Any `team` mode was proposed with its 3 to 4x cost and stayed read-only.
- [ ] Test databases of merged or aborted tracks were dropped.
