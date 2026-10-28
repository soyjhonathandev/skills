---
description: Parallel multi-agent review of code changes with a preset (Quick, Standard, Deep, Money/Tenant, Contract, Custom). Reviewers produce findings; nothing is fixed without your approval.
---

# /review: parallel review with a preset

> Parallel review with an Agent Team and a preset. For phased research and design, use `/team`.
> **Reviewers produce findings; nothing is fixed automatically.** You (the orchestrator) are the only writer of
> session files. Ask ONE question at a time. Every block marked "Print:" is literal output.
>
> Agent Teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in the `env` block of `.claude/settings.json` or
> `~/.claude/settings.json`. Without it, spawn the reviewers as parallel subagents with the Agent tool.

The reviewers are the agents in `~/.claude/agents/` (or the project's `.claude/agents/`). Plan-driven mode
reads the session files `/team` writes in `.claude/sessions/<slug>/` (`contract.md`, `status.json`,
`log.jsonl`); their format is in the `/team` command, section "Session files".

---

## Step 1: What to review

Glob `.claude/sessions/*/status.json`, newest by mtime. If a session exists, read `.slug` and recommend
plan-driven mode.

Print:

```
What should be reviewed?

[0] Plan-driven: the active session's diff against its contract (recommended when a session exists)
[1] Uncommitted and committed changes on this branch (git diff <trunk>...HEAD plus the working tree)
[2] Specific files (I'll list them)
[3] Another branch (I'll name it)
```

Only show [0] when a session exists. Wait.

- **[0] Plan-driven.** Paths: `CONTRACT`, `STATUS`, `LOG` (absolute). Before spawning anyone, hash the
  contract yourself and compare with log line 1:

  ```bash
  { command -v sha256sum >/dev/null && sha256sum "$CONTRACT" || shasum -a 256 "$CONTRACT"; } | awk '{print $1}'
  head -n 1 "$LOG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["payload"]["contract_sha256"])'
  ```

  A mismatch stops the review with `BLOCK (contract drift)`; set status `drift_blocked` if it was `draft` or
  `executing` and append `verdict` and `status_changed`. On match, every reviewer gets the three directive
  lines (`Contract file:`, `Status file:`, `Log file:`), the diff since `planned_against_sha`, and the
  instruction to check the acceptance criteria and global constraints. Reviewers never get status.json or the
  log beyond line 1; each also re-checks the hash per its own agent file.
- **[1]** `git diff <trunk>...HEAD` plus `git diff` and `git status --short` for uncommitted and new files.
- **[2]** Wait for the list.
- **[3]** Ask for the branch, then `git diff <trunk>...<branch> --stat` and the full diff.

---

## Step 2: Preset

Print:

```
Review team:

[0] Quick          code-reviewer
[1] Standard       code-reviewer, architecture-reviewer
[2] Deep           code-reviewer, architecture-reviewer, fresh-eyes, performance-reviewer
[3] Money/Tenant   code-reviewer, architecture-reviewer, security-reviewer, domain-expert
[4] Contract       api-contract-reviewer, architecture-reviewer
[5] Custom         I'll pick agents
```

Recommend one, first, with the reason: Money/Tenant when the diff touches amounts, rates, taxes, balances, the
cash close, tenant scoping, auth or a destructive admin endpoint; Contract when it touches routes, DTOs,
client API services or socket events. Every preset above Quick is an Agent Team: about 3 to 4 times the cost
of a single review. Wait. On Custom, list the reviewer agents and let the developer pick.

---

## Step 3: Spawn

Create an Agent Team named `<repo>-<slug or branch>-review`. Each reviewer loads its own skills from its
definition, reviews the scope from its perspective, and sends its findings to you. Reviewers are read-only:
give each the line `Read-only: produce findings, do not edit any file.`

---

## Step 4: Synthesis

If a finding could be a real issue or a style preference, ask the developer to classify it instead of
deciding.

Print:

```
+----- REVIEW SYNTHESIS ----------------------------+
|                                                    |
|  Consensus (several agents agree):                 |
|    - <finding> file:line (flagged by: agent, agent)|
|                                                    |
|  Conflicts:                                        |
|    - <agent>: <position>                           |
|      <agent>: <counter-position>                   |
|                                                    |
|  Surprises:                                        |
|    - <finding one agent made>                      |
|                                                    |
|  Blocking: <count of Must Fix / Critical / blocking items>
+----------------------------------------------------+

[0] Accept all findings
[1] Show them in detail
[2] Apply the accepted findings
[3] Dismiss
```

On [2], apply only what the developer accepted, reading each file before editing, then offer the same preset
again on the new diff.

In plan-driven mode, append each reviewer's `plan-update` block to `log.jsonl` as events (`verdict`, `problem`,
`opinion`, with `phase_id` from the block, `review` when it names no phase), one line per event, with a
heredoc and a single-quoted delimiter:

```bash
cat >> "$LOG" <<'EOF'
{"ts":"<ISO-8601 UTC>","type":"verdict","phase_id":"review","payload":{"source_agent":"<agent>","verdict":"<verdict>","summary":"<one line>","resolution":"<what the developer chose>","track":null}}
EOF
```

Never `echo` into the log and never use the Write or Edit tool on it.
