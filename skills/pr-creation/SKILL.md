---
name: pr-creation
description: How Jhonathan opens PRs and replies on them: short casual gitmoji title that fits without clipping, a clear short description in his voice, the repo's own template with only Description and "Fixes #N" filled, ready-for-review by default, and short thankful replies to review feedback. Load on any "create/open a PR", "reply to this review", or "fix that review comment" request.
---

# pr-creation

> Loads `writing-style` for all the prose, and shares the icon system with `commit-creation`.
> Everything here is downstream of those: no em dashes, no filler, shorter than your first draft.

## Title

`<gitmoji shortcode> <scope>: <short plain description>`

**Keep it under ~50 rendered characters, 60 is the hard ceiling.** GitHub clips the title on the PR
page and in lists, and a clipped title is worse than a vague one because the end is where the
meaning usually sits. The shortcode renders as one character, so count `✨` not `:sparkles:`.

Real example of the failure, 65 rendered and clipped mid-word:

```
✨ sdk: add app.settings.onChange and the AppSubscriptions su…
```

It should have been something like `✨ sdk: make app settings followable` (35).

**Use casual, everyday vocabulary.** "make X followable" over "introduce the X surface". "drop"
over "remove the unused". "wire up" over "implement the integration for". If a symbol name is long,
say what it does instead of naming it: the body has room for `AppSubscriptions`, the title does not.

**Scope only when it names a non-default area.** `sdk:`, `pwa:`, `desktop:`, `workload:`,
`control:`, `app-host:`, `docs:`, `ci:`. Never `frontend:` for `apps/frontend`, which is the
default context and goes unnamed (0 uses in 1500 commits). Check `git log` before inventing a scope.

No trailing ticket number when the template already links the issue.

## Body

**Use the repo's own PR template.** Fill in **only**:

- **Description**: what and why, in his voice. Clear and short: a couple of plain paragraphs, and
  a `What I did:` bullet list when there is more than one change. No walkthrough of how you
  investigated it, no arguing the change is correct, no restating the diff.
- **`Fixes #N`**: the tracking issue, one line per issue when a PR closes several.

Leave the rest of the template as it comes. Don't invent sections it doesn't have, and don't tick
checklists on his behalf. A one-line note under Screenshots is fine when there is no visual change.

Cut before posting. If the description is longer than the diff deserves, it is too long.

## Replying to review feedback

**Short, casual, and thankful.** Say thanks, say it's fixed, say how in one sentence. That is the
whole shape:

```
thanks, fixed in 7af7b41. Both spots now say settings are followable but don't replay,
so they seed with getAll() instead of wrapping in live().
```

Rules that apply:

- **Thank them, don't grade them.** "thanks" is fine and wanted. Ruling on whether they were right
  is not: no "you're right", no "Good catch" (`writing-style` hard rule 5). When they are wrong,
  open with a bare **"nop"** and give the mechanism.
- **Short SHA is 7 characters** (`7af7b41`), not the 9 `git log --oneline` prints.
- **One or two sentences on the mechanism**, not a recap of the whole change. They read the diff.
- If you did something beyond what they asked, say so in a line and offer to revert it.
- When the point is a code change, skip the prose and leave a GitHub suggestion block.
- Reply **inline on the thread** when their comment was inline; reply at top level only when theirs
  was top level.

## Defaults

- **Always set him as the assignee** (`soyjhonathandev`). Not optional, and not only when asked.
- **Ready for review**, not draft. Open a draft **only** when he asks for one, and when it is a
  draft, say so explicitly in any announcement message.
- Set the milestone when the issue has one.
- Never add a Claude co-author trailer or "Generated with Claude Code" to the PR body.
- `Fixes #N` does not auto-close here: PRs target `staging` and closing keywords only fire against
  the default branch (`main`). The line still links the issue, but someone closes it by hand.

## Announcing it

The Zulip message that announces a PR is a **different artifact**, see the `team-status` register in
`writing-style`: `Hi guys` → "this message is regarding this [Issue](url)" → the PR link on its own
line → why, with decisions attributed to where they came from → `What I did:` + bullets → the ask,
with reviewers as `@**Full Name**` and what specifically he wants eyes on.

If he says "show me the message", output the message **alone**, copy-paste ready, with no commentary
around it.
