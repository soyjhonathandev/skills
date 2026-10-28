---
name: commit-creation
description: How Jhonathan writes commits — gitmoji-prefixed short title, plain-voice body, one concern per commit, and never a Claude co-author trailer. Load on any "commit this" request.
---

# commit-creation

> Loads `writing-style` for the prose. Restored 2026-08-24; the icon system below is **derived from
> real commit history**, not from memory.

## The shape

```
<icon> <optional scope>: <short descriptive title in plain words>

<body: what changed and why, in his voice. Optional — skip it for obvious changes.>
```

## Icons

Gitmoji, and **default to the shortcode form** (`:seedling:`, `:sparkles:`). It is what he uses
(~72% of prefixed commits) and what he corrects titles back to. GitHub renders both identically,
so a nearby commit using the literal emoji is not a reason to switch.

**The table below is the whole set.** Do not reach for an icon outside it because the repo history
happens to contain one. Work that only adds or fixes tests is groundwork: `:seedling:`.

| Shortcode | Emoji | For | Share of that repo's history |
|---|---|---|---|
| `:seedling:` | 🌱 | groundwork, chore, refactor, tests, anything that enables later work | most common (~12%) |
| `:sparkles:` | ✨ | a new feature | ~7% |
| `:art:` | 🎨 | structure, formatting, polish | ~4% |
| `:bug:` | 🐛 | a bug fix | ~3% |
| `:book:` | 📖 | docs | ~1% |
| `:zap:` | ⚡️ | performance | rare |
| `:wrench:` | 🔧 | config / tooling | rare |
| `:package:` | 📦 | dependencies / build | rare |
| `:warning:` | ⚠️ | breaking or large structural change | rare |
| `:ambulance:` | 🚑 | hotfix | rare |

A scope prefix after the icon is common and useful: `:seedling: csp: allow the dev app origins in
connect-src`.

## Rules

1. **NEVER add a Claude co-author trailer** — no `Co-Authored-By: Claude`, no
   "Generated with Claude Code". This is absolute.
2. **One concern per commit.** If the title needs an "and", it is two commits.
3. **Title is short and descriptive**, lowercase-leaning after the icon, imperative or plain
   present. Not a summary of the diff — a statement of what it does.
4. **Body in his plain voice** when a body is warranted: what and why, no walkthrough of the
   investigation, no arguing that the change is correct.
5. All `writing-style` hard rules apply — no em dashes, no filler, shorter than your first draft.
