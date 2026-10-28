# skills

My Claude Code skills: how I write, how I want output shaped, and how I commit, open PRs and report.
Clone once per machine, link into Claude Code, and every project picks them up.

## Install

```bash
git clone git@github.com:soyjhonathandev/skills.git ~/skills
~/skills/install.sh
```

With several Claude accounts, pass each config dir:

```bash
~/skills/install.sh ~/.claude-default ~/.claude-suppli
```

Each skill is a symlink back into this repo, so `git pull` updates every account at once. Anything
already at the target path is moved to `<name>.bak-<timestamp>`, never deleted.

## Skills

| Skill | Load it when |
|---|---|
| `writing-style` | drafting anything that goes out under my name, or writing to me |
| `readable-output` | any long reply, report, list or plan: the shape, not the words |
| `code-comments` | writing or editing code I will push, and again before committing |
| `commit-creation` | "commit this" |
| `pr-creation` | opening a PR or replying to review |
| `eod-report` | the end-of-day update |
| `style-learning` | the loop that keeps the skills above current, used by `/draft` and `/learn` |

## Commands

- `/draft <genre> <topic>` writes a message, PR, issue, reply, proposal or prompt in my voice.
- `/learn` turns the edits I made to those drafts into proposed skill changes, applied only on my yes.

The learning data (`signals.jsonl`, `corpus.md`, `CHANGELOG.md`) is not here. It holds real
messages from work, so it stays in my private context vault at `$CONTEXT_VAULT/_Framework/learning/`.
Without it `/learn` has nothing to read, but every skill still works.
