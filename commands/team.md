---
description: Agent Team orchestration. Plan a team of read-only reviewers to research, design and review a change, approve the cost first, then write an immutable contract and implement it phase by phase or hand it to /parallel.
---

# /team: Agent Team orchestration

> **You (Claude Code) are the orchestrator. The developer is the engineering manager.** Follow this flow
> exactly. Ask ONE question at a time and wait. Every block marked "Print:" is literal output.
>
> Build the plan first, state the Agent Team cost (about 3 to 4 times a single session), and run nothing until
> the developer approves. **Teammates produce findings, never edits.** At every decision point or ambiguity,
> stop and ask. You are the only writer of session files.
>
> This flow uses Claude Code Agent Teams, an experimental feature: set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
> in the `env` block of `.claude/settings.json` (project) or `~/.claude/settings.json`. Without it, spawn the
> same agents as parallel subagents with the Agent tool; teammates then cannot message each other.
>
> Run it as the main agent of a session inside the repo, never as a subagent: a subagent cannot spawn
> subagents.

The agents live in `~/.claude/agents/` (or the project's `.claude/agents/`). Session files live in the repo at
`.claude/sessions/<slug>/`; add `.claude/sessions/` to `.gitignore`. Their format is in "Session files" at the
end of this command.

---

## Step 0: Skills

Glob `.claude/skills/*/SKILL.md` and `~/.claude/skills/*/SKILL.md`. Never hardcode the list. Take each
description from the frontmatter and condense it to a few words. Read the repo's `AGENTS.md` or `CLAUDE.md`
for the repo name, stack and trunk branch. Print:

```
Repo: <repo> · <stack> · trunk <trunk>

Skills available:
 + <skill name>   <a few words>
 + ...
```

A SKILL.md that fails to parse is listed as `(unreadable)`, not skipped.

---

## Step 1: Task kind

Print:

```
What kind of team work is this?

[0] Code review                  review existing changes from several perspectives
[1] Design and plan              design something before building it
[2] Deep investigation           understand a complex flow or a hard bug
[3] Cross-context work           a change spanning several bounded contexts
[4] Money or tenant-sensitive    amounts, rates, taxes, balances, cash close, tenant scoping, auth
[5] API contract change          a new or changed endpoint, DTO or socket event
[6] Custom                       I'll describe the scope
```

Wait. Record the kind; it sets `planning_mode` (`design`, `investigation`, `cross-context`, `money-tenant`,
`contract`, `custom`).

On **[0]**, run the `/review` flow instead. `/team` ends here.

---

## Step 2: Bounded context

If the project documents its bounded contexts (a section of `AGENTS.md` or `CLAUDE.md`, or a docs folder with
one file per area), list them as a numbered menu with `[N] Cross-context` always last. Load the chosen docs.
Wait. If the project documents none, say so and skip this step.

---

## Step 3: Goal

Print:

```
Describe the goal:
- what the end result looks like
- files, routes, endpoints or collections involved, if you know them
- what must NOT change
```

Wait.

---

## Step 4: Ambiguity check

Check the goal against the loaded docs and the code for: vague verbs ("improve", "fix", "clean up"), unclear
scope, several valid readings, missing context that changes the approach, and contradictions with how the
code works today. Also, where they apply: which currency and which rate, which roles may do this, which tenants
are affected, and whether deployed clients depend on the current API.

Ask every ambiguity in one numbered message. Wait. Keep each answer for the Ambiguity log. If nothing is
ambiguous print `Goal is clear. Building the plan.`

---

## Step 5: Team plan

### 5.1 Pick the team

| Task kind | Research | Design | Review |
|---|---|---|---|
| Design and plan | architecture-reviewer, fresh-eyes | architecture-reviewer | code-reviewer, performance-reviewer |
| Deep investigation | architecture-reviewer, fresh-eyes, performance-reviewer when it is about speed | architecture-reviewer | none (findings are the output) |
| Cross-context work | architecture-reviewer (mandatory), domain-expert | architecture-reviewer | code-reviewer, architecture-reviewer, domain-expert |
| Money or tenant-sensitive | domain-expert, security-reviewer | architecture-reviewer | the Money/Tenant preset |
| API contract change | api-contract-reviewer, architecture-reviewer | api-contract-reviewer | the Contract preset, plus security-reviewer when auth or tenant scoping changes |
| Custom | the developer picks | the developer picks | the developer picks |

Add-ons for any kind: the change touches an amount, a rate, a balance or the cash close: add domain-expert and
security-reviewer. It touches an endpoint, DTO or socket event: add api-contract-reviewer. It needs a test
plan: add test-engineer in read-only mode (it proposes tests; it writes nothing in `/team`).

### 5.2 Present the plan

Print:

```
+----- TEAM PLAN -----------------------------------+
|                                                    |
|  Goal:    <one line>                               |
|  Context: <bounded context(s)>                     |
|  Kind:    <task kind>                              |
|                                                    |
|  Stage 1: Research (parallel)                      |
|    Team: <agents>                                  |
|    Each examines: <scope per agent>                |
|    Output: notes on the current state              |
|                                                    |
|  Stage 2: Design                                   |
|    Agent: <agent>                                  |
|    Output: approach, implementation phases with    |
|            files, API contract when relevant       |
|                                                    |
|  Stage 3: Multi-perspective review (parallel)      |
|    Team: <agents>                                  |
|    Output: consensus, conflicts, priorities        |
|                                                    |
|  Then: implementation, phase by phase here or      |
|        through /parallel, if you approve the design|
|                                                    |
+----------------------------------------------------+

Cost: <N> teammates across 3 stages. An Agent Team costs about 3 to 4 times a single session.
Parallel agents save wall-clock time, not tokens.

Review gates: after Stage 1 (research), after Stage 3 (you approve the design and its phases).

[0] Approve and start Stage 1
[1] Adjust the plan
[2] Too much: do it in a single session instead
```

Wait. On [1] adjust and present again. On [2] stop the flow and continue as a normal single-agent session with
the answers already given.

### 5.3 On approve: record the brief

Derive the slug (see "Session files"). Write `.claude/sessions/<slug>/brief.md` with the goal, the task kind,
the bounded contexts, the Ambiguity log from Step 4 (question and answer per line) and `status: draft`.

**Stages are not contract phases.** Research, Design and Review run now, inside `/team`. The contract is
written later, at the design gate in Step 6.4, and its `## Phases` are the implementation phases the design
produced. An investigation that ends without implementation writes no contract.

---

## Step 6: Run the stages

### 6.1 Spawning

For each stage:

1. Create an Agent Team named `<repo>-<slug>-<stage>` (for example `shop-api-batch-split-research`).
2. Spawn each teammate from its agent definition. It loads its own skills.
3. Give each teammate: its scope (files, routes, endpoints, collections), the loaded domain docs, the goal, the
   Step 4 answers, and this line: `Read-only: produce findings, do not edit any file.`
4. Teammates work in parallel, each in its own context window, and may challenge each other's findings.

### 6.2 Mandatory consultation

A teammate stops and you relay to the developer when it meets: a decision with several valid approaches, code
that contradicts the goal, an ambiguous requirement, a tradeoff the developer should weigh, or a risk of
breaking something. Relay it as:

```
Decision needed (from <agent>):

Context: <what the agent is looking at>

[A] <recommended option> (recommended): <gain, cost>
[B] <other option>: <gain, cost>

Which way? (or give me more context)
```

Never continue past a decision point by guessing.

### 6.3 Synthesis after each parallel stage

Print:

```
+----- STAGE <N> SYNTHESIS -------------------------+
|                                                    |
|  Consensus (several agents agree):                 |
|    - <finding> (flagged by: agent, agent)          |
|                                                    |
|  Conflicts:                                        |
|    - <agent>: <position>                           |
|      <agent>: <counter-position>                   |
|      Why each matters: <context>                   |
|                                                    |
|  Surprises:                                        |
|    - <something one agent found that nobody expected>|
|                                                    |
+----------------------------------------------------+

[0] Accept and continue
[1] Show the findings in detail
[2] Resolve the conflicts (I decide)
[3] Re-run this stage with an adjusted scope
[4] Stop here: I have what I need
```

Present conflicts as discussions, recommendation first:

> code-reviewer wants the rate conversion in a shared money utility. architecture-reviewer says the API must
> own the conversion and the client only displays. domain-expert notes the rate must be the snapshot of the
> sale.
>
> [A] API converts and stores the snapshot; the client displays (recommended): one source of truth, needs an
> API change
> [B] Shared utility on both sides: faster now, two places to keep in sync
>
> Which way?

Record each resolution for the contract.

### 6.4 Design gate: write the contract

After the Stage 3 synthesis, print the implementation plan the design produced:

```
+----- IMPLEMENTATION PLAN -------------------------+
|  Phase p1: <name>                                  |
|    goal:   <one line>                              |
|    track:  <(none) | api | app | migration | ...>  |
|    files:  <repo-relative paths>                   |
|    done when: <acceptance criteria>                |
|    ask at: <decision points>                       |
|  Phase p2: ...                                     |
|                                                    |
|  API contract: <(none) | endpoints>                |
|  Shared files owner: <file: phase/track>           |
+----------------------------------------------------+

[0] Approve: write the contract
[1] Adjust
[2] Stop without implementing
```

On **[0]** run "Write the contract" (Session files) with `producer: /team`, the `planning_mode` from Step 1,
`source_brief` the brief file, the phases above, `pinned_skills` (the skills the design relied on, by name),
`pinned_domains` (Step 2 docs, repo-relative), the API contract, and `global_constraints` (from Step 3, Step 4
and the synthesis resolutions, including `shared_files_owner`).

Phases meant for `/parallel` carry a `track` and disjoint `files_to_modify`. Check disjointness before
approving (the one-liner in `/parallel` Step 1.2): an overlap between phases that could run at the same time
is a planning error.

On **[2]**, if no contract exists, go to Step 9.

---

## Step 7: Implementation

Print:

```
Implementation:

[0] Phase by phase here: expert-developer implements each phase, plan-reviewer verifies it (recommended for sequential phases)
[1] /parallel: tracks run in separate worktrees at the same time (needs phases with tracks and disjoint files)
[2] Single agent: you implement in this session, using the approved design as the plan
```

Wait.

- **[0]:** run Step 7.1 below.
- **[1]:** tell the developer to run `/parallel`. It finds the contract by the newest `status.json`.
- **[2]:** implement the contract's phases yourself in this session, then run Step 7.1.4 (closing validation).

### 7.1 Phase by phase

Rules: never re-ask what the contract settled; expert-developer self-reviews before plan-reviewer sees
anything; plan-reviewer assumes drift until proven otherwise; a BLOCK stops progress until fixed or explicitly
overridden; `BLOCK (contract drift)` is never overridable; every decision point goes to the developer.

**7.1.1 Validate.** Status is `draft` or `executing` (`done`, `aborted`, `drift_blocked` are terminal: stop and
say a new plan is needed). The contract exists. Log line 1 parses and is `contract_approved` (else
`BLOCK (log empty)` or `BLOCK (log corrupt)` with file:line). The hash matches (else `BLOCK (contract drift)`:
set `drift_blocked`, append `verdict` and `status_changed`, stop). If HEAD moved since `planned_against_sha`,
warn with both SHAs; it is informational. This session runs in a feature worktree, not the primary checkout
and not on trunk; otherwise stop and print the worktree command (the `worktree-and-branches` skill). Print the
goal, phases, constraints, gate, base SHA and the first 12 chars of the contract hash, and ask `Start? Any
changes?`. A change to scope, phases or constraints means a new plan and a new slug. On confirmation set
status `executing` and append `status_changed`. On resume, skip phases that already have a `phase_completed`
with `PASS`, `PASS WITH NOTES` or an override.

**7.1.2 Each phase.** Print `Phase <id>: <name>`, append `phase_started`, update status (`current_phase_id`,
`current_phase_index`). Spawn expert-developer with a prompt that starts with:

```
Contract file: <CONTRACT>
Status file: <STATUS>
Log file: <LOG>
Read ONLY the contract file (plus log line 1 for the hash). Do not read or write status or log.
Phase to implement: <id>
```

Then the phase block verbatim, a reminder that Pinned Skills and Pinned Domains replace its defaults, the port
and test database to use if it runs anything, and the instruction to self-review, run the validation gate and
end with the `plan-update` block. Relay every `Decision needed` to the developer, recommendation first, and
pass the answer back.

Print its self-review (Fixed, Verified, Gates, Concerns). Then spawn plan-reviewer with the three lines,
`Audit scope: contract + diff + contract_sha256 from log line 1. Do not read status.json or log lines after
line 1.`, `Phase under review: <id>`, `git diff <planned_against_sha>` (working tree included) and
`git status --short`.

**7.1.3 Verdict.** Print the verdict and wait for a choice every time:

- `BLOCK`: `[0] Fix and re-review (repeat until PASS) [1] Show the full review [2] Override the BLOCK (I
  accept the risk) [3] Re-implement this phase`. [0] spawns expert-developer with the must-fix list (same
  three lines), then plan-reviewer again.
- `PASS WITH NOTES`: `[0] Fix and continue [1] Continue as is [2] Show the full review`.
- `PASS`: `[0] Next phase [1] Show the full review [2] Run the validation gate now [3] Show git diff`.
- `BLOCK (contract drift)`: set `drift_blocked`, append `verdict` and `status_changed`, tell the developer to
  plan again for a new slug. No override.

Write the events for every `plan-update` block (routing in Session files): one `phase_completed` with the last
verdict (`"BLOCK (overridden)"` on an override), the decisions, problems and opinions, and one `verdict` per
plan-reviewer run. Update status atomically. Never touch the contract.

**7.1.4 Closing validation.** Run every `validation_gate` command. Spawn plan-reviewer for the cross-phase
review: the three lines, `Cross-phase review: all phases against the whole contract. Log lines after line 1
are not contract.`, and `git diff <planned_against_sha>`. If the contract has an API Contract block, also
spawn api-contract-reviewer in parallel. If `planning_mode` is `money-tenant`, also spawn security-reviewer and
domain-expert. Append each verdict with `phase_id: "cross-phase"`. Print gates, verdicts and each acceptance
criterion of the whole contract (met or not, with evidence), then `[0] Show the full diff [1] Fix what is left
[2] Close`. [1] spawns expert-developer with the remaining items and repeats this step.

**7.1.5 Close.** Status `done`, `current_phase_id: null`, `current_phase_index: null`, append `status_changed`
with reason `cross_phase_pass`. Print: commits follow the `commit-creation` skill; push and PR only if the
developer asks, following the `pr-creation` skill.

---

## Step 8: Closing review

For a last multi-perspective pass before the PR, run `/review` in plan-driven mode with the preset this
plan's kind maps to (Step 5.1 Review column).

---

## Step 9: Cleanup

- Shut down every teammate.
- If a contract exists and never entered execution or `/parallel` (status still `draft`), set the status to
  `done` (design delivered) or `aborted` (abandoned), mirror it in the brief, append `status_changed`. If it
  did enter them, they own the closing status.
- Show `git diff` if anything changed. It should not have: teammates are read-only.

---

## Agent roster

| Agent | Perspective | Focus |
|---|---|---|
| code-reviewer | senior engineer on the team | patterns, anti-patterns, conventions |
| architecture-reviewer | software architect | layers, boundaries, tenant scoping, data access |
| fresh-eyes | new developer | naming, traceability, implicit knowledge |
| performance-reviewer | performance engineer | change detection, bundles, query shape, socket fan-out |
| security-reviewer | attacker | tenant isolation, authz, injection, secrets, uploads, webhooks |
| api-contract-reviewer | contract holder | client, route, DTO and schema agree; breaking changes |
| domain-expert | business authority | money, rates, taxes, balances, cash close, inventory |
| test-engineer | test engineer | the test plan (read-only in `/team`; writes tests during execution and in `/parallel`) |
| expert-developer | implementer | one contract phase at a time |
| plan-reviewer | plan enforcer | contract compliance, hash check, track overlap |

## Review presets

| Preset | Agents | Use it for |
|---|---|---|
| Quick | code-reviewer | a fast pattern check |
| Standard | code-reviewer, architecture-reviewer | most reviews |
| Deep | code-reviewer, architecture-reviewer, fresh-eyes, performance-reviewer | before a large PR |
| Money/Tenant | code-reviewer, architecture-reviewer, security-reviewer, domain-expert | money, rates, balances, cash close, tenant scoping, auth |
| Contract | api-contract-reviewer, architecture-reviewer | endpoints, DTOs, socket events, `/parallel` integration |
| Custom | the developer picks | specific concerns |

---

## Session files

One folder per session, in the worktree: `.claude/sessions/<slug>/`. Gitignored. One writer: the orchestrator.
Subagents return a `plan-update` YAML block and never touch these files.

| File | Mutability |
|---|---|
| `brief.md` | the goal, contexts, Ambiguity log and a `status` line that mirrors status.json |
| `contract.md` | **immutable after write** |
| `status.json` | orchestrator-only, atomic writes (`.tmp`, then `mv`) |
| `log.jsonl` | append-only, orchestrator-only |

### Slug

Lowercase the goal, strip non-ASCII, replace each run of `[^a-z0-9]+` with `-`, trim `-`, keep the first 5
tokens, at most about 40 characters, never ending in `-<digit>`. If the folder exists, append `-2`, `-3` and so
on, lowest unused first. Discovery: glob `.claude/sessions/*/status.json`, take the newest by mtime.

### Hashing

```bash
{ command -v sha256sum >/dev/null && sha256sum "$CONTRACT" || shasum -a 256 "$CONTRACT"; } | awk '{print $1}'
head -n 1 "$LOG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["payload"]["contract_sha256"])'
```

SHA-256 over the raw bytes of the whole file, lowercase hex. The braces matter: without them the pipe binds
only to `shasum`. The canonical value is `payload.contract_sha256` on log line 1; status.json holds a cache,
and on disagreement the log wins. Any byte change to the contract is `BLOCK (contract drift)`, which cannot be
overridden. Changing scope means a new contract with a new slug.

### Write the contract

1. Capture `approved_at` (ISO-8601 UTC), `planned_against_sha` (`git rev-parse HEAD`), `branch`
   (`git branch --show-current`).
2. Read the validation gate (typecheck, lint, unit test commands) from the repo's `AGENTS.md` or `CLAUDE.md`.
   If they are not written down, ask the developer for them. The contract copies them so later edits cannot
   change what it was approved against.
3. Write `contract.md` from the template below, every placeholder substituted. From here on it is immutable.
4. Compute the hash.
5. Append `contract_approved` as log line 1.
6. Write `status.json` with `status: "draft"`, both timestamps `approved_at`, `current_phase_id: null`,
   `current_phase_index: 0`, `tracks: null`.
7. Print the three paths and the first 12 hash chars. From now on every subagent spawn prompt starts with:

   ```
   Contract file: <absolute path>
   Status file: <absolute path>
   Log file: <absolute path>
   ```

Contract template:

```markdown
# Contract: <slug>

<!-- DO NOT HAND-EDIT. Immutable after write: any byte change breaks contract_sha256 and the next review
     returns BLOCK (contract drift). To change scope, plan again for a new slug. -->

## Metadata

- **slug:** <slug>
- **repo:** <repo>
- **source_brief:** <absolute path to brief.md>
- **planning_mode:** <design | investigation | cross-context | money-tenant | contract | custom>
- **producer:** /team
- **approved_at:** <ISO-8601 UTC>
- **planned_against_sha:** <sha>
- **branch:** <branch>

## Pinned Skills

- <skill name>

## Pinned Domains

- <repo-relative path to a domain doc>

## API Contract

<"(none)", or one block per endpoint:>
- **endpoint:** <METHOD /path>
- **request:** <fields with types; money as integer minor units or a decimal type plus currency>
- **response:** <fields with types>
- **errors:** <status codes and the standard error shape>
- **auth and tenant scoping:** <who may call it; how the tenant is resolved and enforced>
- **pagination and filters:** <or "(none)">
- **breaking change:** <no | yes, with the migration path for existing clients>

## Global Constraints

- **must_not_modify:** <globs>
- **must_preserve:** <invariants, e.g. "every query stays tenant-scoped">
- **shared_files_owner:** <"file: track" pairs for /parallel, or "(none)">
- **scope_boundary:** <one sentence: in scope, out of scope>
- **validation_gate:** <typecheck, lint and unit test commands> + `git diff` review (every phase)

## Phases

### Phase 1: <name>

- **id:** p1
- **goal:** <one sentence>
- **track:** <"(none)", or a track id for /parallel: api | app | e2e | migration | docs, optionally with a kebab suffix>
- **depends_on:** <"(none)", or phase ids that must merge first>
- **files_to_modify:**
  - <repo-relative path, "(new file)" when it does not exist yet>
- **acceptance_criteria:**
  - [ ] <testable criterion>
- **constraints:**
  - <phase-specific constraint>
- **expected_decision_points:**
  - <known fork in the road: the implementer must ask here>
```

`files_to_modify` are repo-relative so a track worktree, the orchestrator worktree and a reviewer read the
same path. The API Contract is mandatory when any phase adds or changes an endpoint, a DTO or a socket event.

### status.json

```json
{
  "schema_version": 1,
  "slug": "<slug>",
  "contract_path": "<absolute>",
  "log_path": "<absolute>",
  "contract_sha256": "<64 hex>",
  "status": "draft",
  "created_at": "<ISO-8601 UTC>",
  "last_updated_at": "<ISO-8601 UTC>",
  "producer": "/team",
  "current_phase_id": null,
  "current_phase_index": 0,
  "tracks": null
}
```

`status` is `draft | executing | done | aborted | drift_blocked`; the last three are terminal. Allowed moves:
`draft` to `executing` when execution starts; `executing` to `done` after the cross-phase review passes;
`draft` or `executing` to `aborted` when the developer abandons it, or to `drift_blocked` on
`BLOCK (contract drift)`. Every status change is paired with a log event. `tracks` is filled only by
`/parallel`.

### log.jsonl

One JSON object per line: `{"ts":"<ISO-8601 UTC>","type":"<type>","phase_id":"<id or null>","payload":{}}`.
`phase_id` is a phase id, `cross-phase`, `integration`, or `null`.

| type | payload |
|---|---|
| `contract_approved` (line 1, once) | `slug`, `contract_path`, `contract_sha256`, `producer`, `planning_mode`, `branch`, `planned_against_sha` |
| `status_changed` | `from`, `to`, `actor`, `reason` |
| `phase_started` | `name`, `index`, `track` |
| `phase_completed` | `name`, `verdict`, `track` |
| `decision` | `question`, `options`, `choice`, `rationale`, `user_approved` |
| `problem` | `source_agent`, `description`, `resolution` |
| `opinion` | `source_agent`, `opinion`, `developer_action` |
| `verdict` | `source_agent`, `verdict`, `summary`, `resolution`, `track` |
| `track_dispatched` | `track`, `mode`, `branch`, `worktree`, `session_name`, `port`, `test_db`, `depends_on`, `base_sha` |
| `track_merged` | `track`, `branch`, `into`, `merge_sha` |

Routing a `plan-update` block: `phase_id` + `status` (+ `verdict`) become one `phase_completed`; each
`decisions[]` item one `decision`; each `problems[]` item one `problem`; each `opinions[]` item one `opinion`
with `source_agent`; a reviewer's `verdict` one `verdict`; `track`, `head_sha` and `worktree` update
`tracks.<id>` in status.json.

Append with a heredoc and a single-quoted delimiter, which disables shell expansion:

```bash
cat >> "$LOG" <<'EOF'
{"ts":"2026-01-01T12:00:00Z","type":"problem","phase_id":"p1","payload":{"source_agent":"expert-developer","description":"...","resolution":"..."}}
EOF
```

Never `echo` (some shells rewrite `\n` inside it), never the Write or Edit tool on the log, never an unquoted
delimiter. Concurrent appends are unsafe: the orchestrator appends one event at a time.

The log is an audit trail, not a tamper-proof ledger: only the contract is tamper-evident, through the hash on
line 1.
