---
name: eod-report
description: The end-of-day report Jhonathan posts to his team in Zulip. Load on EOD / daily-update requests. Follows the team's approved EOD Writing Guide, not a personal format.
---

# eod-report

> The team's approved format, from the team's **EOD Writing Guide**. The whole team writes
> EODs this way, so the shape is fixed and only the content changes. Confirmed 2026-08-26 against
> the guide plus two of his real EODs; the corpus holds a full sample.

## Document shape

Markdown headers, not bold labels. `# EOD (last 2 days)` as the title, then `## Section` per block.
One blank line between a header and its list, and before the next header. He posts the raw markdown
into Zulip, so give it as a fenced block when he asks for something to paste.

## Line shape

```
- <emoji> <Action, only when needed> <Title> [repo#number](link)
  - <sub-bullet: what it closes, what it unblocked, what changed after review>
```

**Titles are plain.** The written guide shows `**[Title]**`, but he posts them unbolded, so do not
bold them.

**Never repeat what the emoji already says.** `:pr-merged:` means merged, so do not write "Merged".
`:issue:` means an issue, so no "Opened" or "Created". **Strip the gitmoji** from PR titles.

A section may open with a plain intro line before its bullets, e.g. *"Launchpad follow-ups: #7534,
#7535 and #7537 are done, one left:"*. Reviews carry their state in parens at the end: `(merged)`,
`(still open)`.

## Emoji

| Code | Use |
|---|---|
| `:pr-draft:` | Draft PR |
| `:pr-open:` | Open PR |
| `:pr-merged:` | Merged PR |
| `:pr-closed:` | Closed PR |
| `:issue:` | Issue |
| `:check:` | Completed task, or a review |
| `:tools:` | Ongoing task |
| `:warning:` | Blocker |
| `:right:` | Next task |

Reviewed: `- :check: Reviewed <Title> <link> (merged)`.
Reviewed and merged: `- :pr-merged: Reviewed & merged <Title> <link>`.

## Sections

`Pull requests`, `Reviews`, `Issues`, `Completed`, `Ongoing`, `Blockers`, `Next`, `Notes`. Use only
the ones with content. A block of remaining work gets a **task-specific header** rather than a
generic one, e.g. *"What's left for launchpad + the workload SDK integration"*. `Notes` closes the
report with cross-cutting context that belongs to no single line.

## Verbs

Completed is past tense: Reviewed, Updated, Tested, Fixed, Investigated, Documented, Deployed,
Implemented, Configured, Refactored. Ongoing is the present participle: Reviewing, Updating,
Testing, Fixing, Investigating. Next is the base form: Continue, Review, Run.

Never `:check:` something still in progress. Be specific: *"Fixed the login validation error"*, not
*"Worked on login"*.

## Voice

All `writing-style` hard rules apply: no em dashes, no corporate filler, shorter than the first
draft. Sub-bullets stay plain and first person, one thought per clause, never compressed
consultant-style (*"zero file overlap"*, *"validated X: A holds (B)"*). Explain technically but
simply, in his own words, no AI analogies. Mentions use `@**Full Name**`. Be honest about what did
not land: an open or blocked item stated plainly is in character.
