---
name: code-comments
description: What may and may not be written as a comment in code Jhonathan will push. Only load-bearing comments survive; issue and PR references, thinking-process narration, and restatements of the line below never get committed. Load before writing or editing any source file, and again before committing.
---

# code-comments

> The default is **no comment**. A comment has to earn its line by saying something the
> code cannot, to a reader who is not you and was not here.
>
> Source: 2026-09-03. Two PRs came back with 64 and 17 added comment lines. After the pass
> he asked for, 27 and 11. Roughly half were restating the line under them.

## Never commit

**Issue or PR numbers.** `// fixes the bug from #7398`, `// see #7109`, `// split out of
#6643`. That history belongs in git and in the tracker, where it stays linked and current.
A number in a file rots the moment the issue is renamed or closed. This is the one that
gets violated most, because the issue is on screen while the code is being written.

**The thinking process.** `// first I tried X but it deadlocked`, `// turns out the host
sends this twice`, `// after debugging this is actually the parent`. Nobody reading the
file needs the route you took, only where you arrived.

**Restatements.** If the sentence is the signature or the line below it in English, delete
it. `/** Current values. */` over `function appSettings(): AppSettings`. `// stop the
subscription` over `sub.stop()`.

**Arguing that the code is correct.** That is review-talk. It belongs in the PR, where
someone can disagree with it.

**Section banners and decoration.** `// ---- helpers ----`, `// === setup ===`.

## Worth committing

Only four kinds, and each in as few lines as it takes:

**A footgun.** A language or runtime behavior that will bite the next edit.
`// Map iterators visit entries added mid-iteration, so snapshot the keys first.`

**Why not the obvious thing.** When the code looks wrong until you know the constraint.
`` // `base`, not `resolve`: the route is a plain string, so there is no route id. ``

**A unit or a contract the types do not carry.**
`` // `refreshInterval` is in seconds. ``

**An invariant a future edit would break.**
`` // `Record<never, …>` accepts anything, so a helper that collapsed to `never` would make
every pin vacuous. ``

## Shape

One line beats three. Three beats a paragraph. If a comment needs a paragraph, the thing
it describes probably needs a better name or a smaller function.

Write what is true about the code, not what you did to it. Present tense, no "we", no "I".

All `writing-style` hard rules apply: no em dashes, no filler, and cut it before you commit.

## Before committing

Read every comment in the diff and delete the ones that do not fit the four kinds above.
Doing this at commit time catches what you did not notice while writing.

```bash
git diff --unified=0 | grep -E "^\+\s*(//|\*|/\*)"
```

Then check nothing carries a ticket reference:

```bash
git diff --unified=0 | grep -E "^\+.*(//|\*)" | grep -E "#[0-9]{3,}"
```

Both belong in the commit body instead, where the reference stays useful.

## Exceptions

A file sharing a header **verbatim** with sibling copies keeps it. Duplicated boilerplate
across N files is a consistency contract, so check the siblings before trimming one.

Pre-existing comments are not yours to police. Leave them unless your change made them
wrong, in which case fix them in the same commit rather than leaving a contradiction.

Doc comments on a public API are documentation, not commentary, and follow the same rules
as prose: say what a caller cannot infer from the signature (no-replay semantics, units,
what throws), and nothing else.

## Related

`writing-style` (the words, and the code-comment register this expands) · `commit-creation`
(where the history and the issue numbers actually belong).
