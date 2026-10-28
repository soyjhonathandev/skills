---
title: draft
type: command
delegates_to: "[[style-learning]]"
tags: [framework, command, writing]
---

# /draft — write something in your voice, then learn from your edits

> The generation front door and the natural capture point of the learning loop. Produces a PR
> description, issue, proposal, Zulip/Slack message, reply, or prompt in Jhonathan's voice (via the
> `writing-style` skill), ready to copy-paste. When he edits it before sending, that edit is captured
> as a signal for `/learn`. Uses `writing-style` + `style-learning`.

## Usage

- `/draft <genre> <what it's about>` — e.g. `/draft pr adds smart CI that runs only affected-domain
  e2e tests`, `/draft message tell @frontend the launchpad PR is ready for review`, `/draft reply <paste
  the thread>`, `/draft proposal <topic>`, `/draft prompt <the task you want to give an agent>`.
- Genres: `message` (Zulip/Slack), `reply`, `pr`, `issue`, `review` (review comment), `proposal`,
  `prompt`, `eod` (delegates to the `eod-report` skill).
- If genre or audience is unclear, ask once, then draft.

## Steps

1. **Load the voice.** Apply the `writing-style` skill for the target genre (mode A — writing as
   Jhonathan). For `eod`, use the `eod-report` skill instead.
2. **Draft.** Write it in his voice: technical but simple, his own words, no AI analogies, no em
   dashes, no filler. Keep facts exact; don't invent PR/issue numbers, links, or details he didn't
   give (use `[____]` placeholders and list them under the draft).
3. **Deliver for copy-paste.** Output the draft as one fenced code block (```` ```markdown ````) so he
   can copy it straight from the terminal. Below it, list any placeholders to fill and anything you
   were unsure about.
4. **Capture the edit.** If he then changes the draft before using it, or tells you what was off,
   append that delta to `signals.jsonl` as a `kind:"edit"` (or `"correction"`) signal per the
   `style-learning` skill. That's the highest-value training data. Don't edit the skill now; `/learn`
   folds it in later with his approval.

## Hard rules

- Never fabricate facts (numbers, files, links, names). Placeholders, not guesses.
- Match length to the genre: a one-line reply stays one line; a proposal uses the full arc.
- Same two-mode discipline from `writing-style` (this command is always mode A, as Jhonathan).
- Capture is automatic and safe; it changes no skill.

## Related

[[style-learning]] · [[learn]] · [[learning/README|learning]] · writing-style skill · eod-report skill
