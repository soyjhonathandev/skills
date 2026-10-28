---
title: learn
type: command
delegates_to: "[[style-learning]]"
tags: [framework, command, learning]
---

# /learn — distill how you write into the skills

> The **distill** half of the continuous-learning loop. Capture happens automatically during daily
> usage (see the `style-learning` skill); `/learn` is the deliberate, approval-gated step that turns
> the captured signals into concrete edits to your writing skills. It never changes a skill without
> your yes. Runs the `style-learning` skill. Corpus lives in `_Framework/learning/`.

## Modes

- **`/learn`** (default) — **distill**: read new signals, propose skill edits, apply the approved ones.
- **`/learn capture "<observation>"`** — manually log a signal right now (e.g. you want to record a
  preference on the spot). Appends one line to `signals.jsonl`, changes no skill.
- **`/learn status`** — show how many `new` signals are waiting, by genre, and the open gaps.

## Reads

- `$CONTEXT_VAULT/_Framework/learning/signals.jsonl` — the raw capture log.
- `$CONTEXT_VAULT/_Framework/learning/corpus.md` — the curated sample library.
- The target skills (global): `~/.claude/skills/{writing-style,eod-report,style-learning}/SKILL.md`
  — the single canonical copy; the per-account dirs symlink to it, so editing it once is enough.

## Writes (only on approval)

- Targeted edits to the relevant skill `SKILL.md`, **synced across all three profiles**.
- `signals.jsonl`: flip processed signals `new → distilled` (with `applied_to`) or `→ rejected`.
  Append-only discipline: write status changes as **new** appended lines that supersede, or rewrite
  is allowed here since it's the loop's own bookkeeping file — but never lose a signal's evidence.
- `corpus.md`: promote the best evidence, prune weak samples (keep it small).
- `CHANGELOG.md`: one appended entry describing the distillation.

## Steps (distill mode)

1. **Gather.** Read `signals.jsonl`, take `status:"new"`. If none, say so and stop (nothing to learn).
   Group by `genre` + `kind`.
2. **Cluster and decide.** For each group, work out the **smallest** change that captures it:
   - a sharpened rule or a new example in `writing-style` (prefer sharpening an existing rule over
     adding a new one),
   - a tweak to a per-genre note,
   - a fix to `eod-report`,
   - or, if one genre now has enough distinct signal to stand alone, **propose graduating it** into its
     own skill (e.g. `pr-writing`, `prompt-craft`) instead of overloading `writing-style`.
   If two signals conflict, don't apply both — surface the conflict and ask which wins.
3. **Propose.** Show each proposed diff with the evidence (the signals) behind it. **Stop for approval.**
4. **Apply approved only.** Make minimal edits. Sync every edited skill across the three profiles and
   verify identical (hash). Flip the applied signals to `distilled` with `applied_to`; mark the rest
   `rejected` with a one-word reason. Keep the two-mode scope-C behavior intact.
5. **Prune + log.** Promote the strongest evidence into `corpus.md`, drop weaker duplicates, append a
   `CHANGELOG.md` entry (date, skills touched, change, source signals, remaining gaps). Report what
   changed and what's still an open gap.

## Hard rules

- **Approval-gated.** No skill edit without an explicit yes (matches [[ORCHESTRATOR]] §1 "developer
  decides"). Capture is automatic; distill is not.
- **Sync or it didn't happen.** A skill edited in one profile must be copied to all three; verify.
- **Don't bloat or degrade.** Fewer, sharper rules beat more rules. Don't let the skill drift.
- **Separation + redaction** ([[project-separation]], [[secret-redaction]]) apply to everything the
  loop writes.

## Related

[[style-learning]] · [[draft]] · [[learning/README|learning]] · [[SKILLS-MAP]] · [[ORCHESTRATOR]] ·
[[sync-context]] (bookkeeping close-out is analogous, but for context notes, not writing style)
