# skills

My Claude Code setup: how I write, how I want output shaped, how I commit and open PRs, the
engineering practices I hold code to, and the agent squad that plans, builds and reviews with me.
Clone once per machine, link into Claude Code, and every project picks it up.

## Install

```bash
git clone git@github.com:soyjhonathandev/skills.git ~/skills
~/skills/install.sh
```

With several Claude accounts, pass each config dir:

```bash
~/skills/install.sh ~/.claude-default ~/.claude-suppli
```

Each skill, agent and command is a symlink back into this repo, so `git pull` updates every account at once. Anything
already at the target path is moved to `<name>.bak-<timestamp>`, never deleted.

## Skills

How I write and work:

| Skill | Load it when |
|---|---|
| `writing-style` | drafting anything that goes out under my name, or writing to me |
| `readable-output` | any long reply, report, list or plan: the shape, not the words |
| `code-comments` | writing or editing code I will push: default to no comment |
| `commit-creation` | "commit this" |
| `pr-creation` | opening a PR or replying to review |
| `eod-report` | the end-of-day update |
| `style-learning` | the loop that keeps the skills above current, used by `/draft` and `/learn` |
| `decision-protocol` | deciding what to settle alone and what to ask first |

Good practices, stack-agnostic: `good-practices` (read first on every change), `architecture`,
`api-design`, `api-contract`, `logging-observability`, `import-conventions`, `test-audit`,
`e2e-testing`, `secret-redaction`, `customer-data-protection`, `multi-tenancy`, `money-and-currency`.

Angular: `angular-architecture`, `angular-good-practices`, `angular-forms`, `angular-state`,
`angular-testing`, `angular-upgrade`, `styling`.

Node and Express: `express-architecture`, `express-good-practices`, `express-security`,
`mongodb-mongoose`, `realtime-socketio`.

Parallel work: `parallel-sessions`, `worktree-and-branches`.

## Agents

The squad that `/team` and `/review` put together. Reviewers only report findings; code is written
by `expert-developer` and, for tests, `test-engineer`.

| Agent | Role |
|---|---|
| `plan-reviewer` | checks the implementation matches the approved plan exactly, and that tracks don't touch the same files |
| `expert-developer` | implements one approved phase and self-reviews |
| `code-reviewer` | the general review against the practice skills |
| `architecture-reviewer` | layering, boundaries, where code lives |
| `api-contract-reviewer` | client, route, DTO and schema stay in agreement |
| `security-reviewer` | tenant isolation, roles, injection, rate limits, CORS, tokens, uploads, PII |
| `performance-reviewer` | queries, bundle size, rendering, hot paths |
| `test-engineer` | writes unit, integration and e2e tests that pass the `test-audit` gate |
| `domain-expert` | business rules, checked against the project's notes |
| `fresh-eyes` | reads the change cold, with no context, to catch what the others assume |

## Commands

- `/draft <genre> <topic>` writes a message, PR, issue, reply, proposal or prompt in my voice.
- `/learn` turns the edits I made to those drafts into proposed skill changes, applied only on my yes.
- `/team <task>` plans the work with the squad, states the cost, and runs nothing until I approve.
- `/review` runs several reviewers on the current change in parallel, with presets from quick to deep.
- `/parallel` runs the tracks of an approved plan at once, one worktree, branch and port per track.

The stack skills fit a web app with an Angular client and an Express/MongoDB API. Agents skip any
skill that is not installed, so the squad still works on other stacks with the general ones.

The learning data (`signals.jsonl`, `corpus.md`, `CHANGELOG.md`) is not here. It holds real
messages from work, so it stays in my private context vault at `$CONTEXT_VAULT/_Framework/learning/`.
Without it `/learn` has nothing to read, but every skill still works.
