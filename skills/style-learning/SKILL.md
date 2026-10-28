---
name: style-learning
description: The continuous-learning loop behind the writing skills — capture signals from how Jhonathan edits and corrects drafts, then distill them into approval-gated skill edits via /learn. Load alongside writing-style, and on /draft and /learn.
---

# style-learning

> The engine of the "learn from me" loop. **Capture is cheap, automatic and safe; distilling is
> deliberate and approval-gated.** Appending a signal changes no skill. Only `/learn` edits a
> skill, and only what he approves.

```
daily usage ──capture──▶ signals.jsonl / corpus.md ──/learn (distill)──▶ skill edits (he approves)
     ▲                                                                          │
     └──────────────────────── skills apply on every write ◀───────────────────┘
```

## Where it lives

Everything is in the vault so it travels between machines:

| File | What | Write mode |
|---|---|---|
| `$CONTEXT_VAULT/_Framework/learning/signals.jsonl` | Append-only raw capture log, one JSON object per line | append (`>>`) only, never rewrite |
| `$CONTEXT_VAULT/_Framework/learning/corpus.md` | Curated tagged sample library — the best few per genre | curated edits |
| `$CONTEXT_VAULT/_Framework/learning/CHANGELOG.md` | Distillation history | append |

Target skills (single canonical copy, symlinked into each account dir):
`~/.claude/skills/{writing-style,eod-report,pr-creation,commit-creation}/SKILL.md`.

## Capture — what counts as a signal

In descending order of value:

1. **His edits to a draft you gave him** (the draft→final delta) — the highest-signal thing there is.
2. **Explicit corrections** ("less formal", "never say X", "shorter").
3. **Raw samples he pastes** in his own words.
4. **Preferences he states** about how he wants things written.

Signal shape:

```json
{"ts":"2026-08-24","genre":"review-comment","kind":"correction","observation":"<the rule, stated as a rule>","evidence":"<the actual before/after or quote>","source":"<where it happened>","status":"new"}
```

`genre` uses the corpus genres (`casual-reply`, `technical-explanation`, `team-status`,
`pr-issue-desc`, `review-comment`, `proposal`, `prompt`, `eod`, `cover-letter`, `application-form`,
`speech-deck`, `method`, or `all`). `kind` is `edit` | `correction` | `preference` | `sample`.
`status` goes `new` → `distilled` when `/learn` consumes it.

## Distill — the `/learn` procedure

1. Read all `status:new` signals; cluster by genre and by the rule they imply.
2. Propose the **smallest** edit to the relevant skill that captures the cluster. Prefer sharpening
   an existing rule over adding a new one.
3. Show the diff. **Apply only what he approves.**
4. Flip consumed signals to `status:distilled`.
5. Promote genuinely good real examples into `corpus.md` — and drop a weaker sample of the same
   genre, so the corpus stays small.
6. Append a CHANGELOG entry: date, skill(s) touched, the change, the signals it came from, and any
   gaps still open.

## Rules

- **Watch for repeats across genres.** A correction appearing in a fourth or fifth genre is not a
  per-genre note, it is a hard rule. ("Default shorter" earned hard-rule status this way.)
- **A later signal can refine an earlier one** rather than contradict it — the "no emojis"
  correction was refined by his own sent message closing with `:pepepray:`. Record the refinement,
  don't just overwrite.
- **Project separation holds** — a captured sample about one project's work never gets stored in a
  way that names another project. The corpus is about voice and method, not project facts.
- **Secrets by reference only** — never paste a real secret value into a sample.
- **The corpus stays small.** A few strong samples per genre beat a dump.

## Known gaps

Real `prompt` samples (his plan-mode prompts) and standalone `pr-issue-desc` samples are still thin.
Capture them when they occur.
