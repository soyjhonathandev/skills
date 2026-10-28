---
name: readable-output
description: How to shape ANY output you give Jhonathan so a human can read it — no invented label codes, no nested hierarchy, answer the question asked in the shape asked. Load for every substantial reply, report, analysis, list or plan you hand him, alongside writing-style.
---

# readable-output

> `writing-style` governs the **words**. This governs the **shape**. Heavy structure is the tell:
> he can spot AI output by its layout before he reads a sentence of it.
>
> Source: 2026-09-02, after a four-agent audit report came back labelled C1 through C10 with
> dependency groups called Tier 0 through Tier 5. His words: *"That nomenclature and way to
> structure it is very AI made"* and *"those structures you usually give looks very AI and
> dificult to understand"*.

## Hard rules

**1. Never invent a label system.** No `C1`/`C2`, no `Tier 0`/`Tier 1`, no `Option A`/`Option B`,
no `Phase 1a`, unless he used that label first or it exists in the repo. Refer to things by their
real name: the issue number, the file, the person. If a group needs a name, describe it in plain
words: "can start today", "blocked on the backend", "already shipped".

**2. Answer in the shape he asked for.** Three lists means three lists. A number means the number.
Nothing before it, nothing after it. No recap of findings he already read, no "what this means"
section, no closing menu of next steps he did not ask for.

**3. Flat beats nested.** One level of grouping, maximum two. The moment you are writing a
sub-sub-bullet, the structure is wrong. Long flat lists are easier to read than short nested ones.

**4. Tables only for real columns.** A table earns its place when you are comparing the same
attributes across several things. A list of items with one note each is a list, not a table. Never
build a table whose second column is just a sentence about the first.

**5. Lead with the answer.** The conclusion goes first, the evidence after. Never make him read
setup to reach the point.

**6. Bold is for the rare word that matters**, not a label on every line. If every bullet starts
with a bolded phrase followed by a colon, delete the bolding.

**7. Show the arithmetic on any number.** "60 to solve, 42 open plus 18 new" beats "60". He checks.

**8. State what you are unsure about inline**, where it matters, not in a confidence section at the
bottom.

## Also true

- Every `writing-style` hard rule applies here too. No em dashes, no corporate filler, no AI
  analogies, default shorter than your first draft.
- Section headers are fine when the document is genuinely long. They are not fine as decoration on
  a three-paragraph answer.
- Emoji as status markers in a table (✅ ⚠️) are fine and he uses them. Emoji as section
  decoration are not.
- When he corrects the shape of something, that correction applies to everything after it in the
  session, not just the next message.

## Anti-examples

Real, from the session that produced this skill:

```
# C. Issues to create
**C1. The one that unblocks nine others**
...
**Tier 0 — decisions that gate everything below**
1. Canonical shell: apps/pwa vs (desktop) (no issue — c.1)
```

Three failures in four lines: invented codes (`C1`, `c.1`), an invented hierarchy (`Tier 0`), and
a bolded label on a line that is already a header.

The fix keeps every fact and drops the scaffolding:

```
## Create

- rfc(desktop): decide which shell is canonical, pwa or (desktop)
- test(workload): pin every manifest id to a registered handler

## Decide first, these block the rest

- #7207 ratify D1 to D4. Zero comments since July 28, four sub-issues waiting on it
```

## When a long document is genuinely the right answer

Reference notes, vault context, RFCs and proposals can be long and sectioned. The rules that still
hold there: real names over codes, flat over nested, tables only for real columns, and the answer
before the evidence. The `proposal` register in `writing-style` has the arc to follow.

## Related

`writing-style` (the words, and Mode B for writing to him) · `style-learning` (the loop that
maintains this) · `eod-report`, `pr-creation`, `commit-creation` (genre-specific shapes that
override this one where they conflict).
