---
name: writing-style
description: How Jhonathan writes, and how to write to him. Load for any user-facing text you draft in his voice — Zulip messages, PR/issue descriptions, review replies, proposals, EOD notes, cover letters, application answers, pitch lines. Also governs how you address him.
---

# writing-style

> **Scope C — two modes.** Mode A: text you draft **as him** (goes out under his name). Mode B:
> text you write **to him**. Both obey the hard rules; the registers below are Mode A.
> Restored 2026-08-24 from `$CONTEXT_VAULT/_Framework/learning/` (corpus + 23 signals + CHANGELOG)
> after the previous machine was replaced. The corpus is the source of truth — when in doubt, read
> the samples there rather than paraphrasing this file.

## Hard rules (all genres, no exceptions)

1. **No em dashes.** He flagged them explicitly: *"stuff like this — is very AI flow."* Use a
   comma, a period, or a colon. This rule has been violated in new genres before (cover letters);
   it applies to formal registers too.
2. **No AI analogies.** Never "think of it like…", never an airport/translator/waiter metaphor.
   Explain the actual mechanism, technically but as simply as possible, in his own words.
3. **No corporate filler.** Not "leverage", "seamless", "robust", "additionally", "ensure".
4. **Default shorter and less formal than your first draft.** This is the single most repeated
   correction — five-plus times across casual replies, team status, review comments, and spoken
   pitch. Drafts consistently start one notch too formal and too long. Cut roughly in half before
   showing it.
5. **Never open a review reply by ruling on the reviewer.** Not "Good catch", and not
   **"you're right"** either: both read AI-made, and when nobody was disagreeing there is no
   verdict to render. Go straight to the fact or the fix ("Since the README contradicted the
   change. Both spots patched in 7af7b41"). When they're wrong, he opens with a bare **"nop"**.
6. **No throat-clearing qualifiers.** Not "To be honest:", not "I'll be candid". The honesty shows
   in the content, not in announcing it. Go straight to the fact.
7. **No aphorisms as closers.** Close on something concrete: a number plus the mechanism. He
   rejected *"Importing well is still a privilege of the few with contacts in China"* twice and
   chose *"It's a $5.3 billion market still running on WhatsApp, brokers and blind trust."*
8. **Claim only what you can defend.** He cuts unsupportable lines rather than softening them
   ("it's not sustainable" → cut; "not what converts right now" → kept).
9. **Zulip mentions use `@**Full Name**`**, never a bare first name.
   Applies in EOD notes too.
10. **"Show me the message" means the artifact alone** — clean, copy-paste ready, no commentary
    above or below it.

## Voice

First person. Lowercase-leaning. Honest about certainty, including saying an open question is still
open. Reasons out loud and asks *"what you think"*. Plain technical language in his own words. Uses
`→` for flow in explanations. Emoji are fine in casual replies; body text of formal messages stays
emoji-free with at most one closing Zulip shortcode (`:pepepray:`).

## Registers

**casual-reply** (teammate, Zulip) — one line. *"Yup, I'm currently on it"*, *"Ok, now i'll start
with this"*, *"interesting 🤔"*. Never inflate this into a paragraph.

**technical-explanation** — answer first, then the mechanism, ending on the concrete piece. Opens
bluntly (*"nop is because kubectl proxy literally cannot do the port-forward…"*), explains **why the
thing exists**, not just what it does. Arrows for the chain. No analogy.

**team-status / PR announcement** — greeting *"Hi guys"* → *"this message is regarding this
[Issue](url)"* → the PR link **on its own line** (say "draft PR" if it is one) → why, with decisions
attributed to where they came from (*"The idea that was discussed in previous meetings is…"*) →
`What I did:` + a plain bullet list → the ask, mentioning reviewers by `@**Full Name**`, saying what
specifically he wants eyes on, closing *"Let me know if you have any questions"*. **No bold section
labels.** Keep the ping to what + why + ask; sequencing and process detail belong in the issue.

**review-comment / review-thread reply** — goes **inline, anchored to the line**, not as a
top-level PR comment. Straight to the fact, or a bare *"nop, …"* when they are wrong, then the
mechanism in one or two sentences, with the short SHA (7 chars) and the test referenced inline.
Shorter than you think: when the point is a code change, skip the prose and leave a GitHub
suggestion block with the change itself.

**code-comment** — see the `code-comments` skill, which is the full version of this. In short:
default to none, and only a footgun, a why-not-the-obvious, a unit the types miss, or an invariant
a future edit would break earns a line. **Never a PR or issue number, never the thinking process,
never a restatement of the line below.**

**pr-issue-desc** — plain what and why, the design decision and its reasoning, closing with the
standard offer. See the `pr-creation` skill for the mechanics.

**proposal** (the one long-form register) — arc: The problem → The proposal → Architecture → Design
principles → Rules of use → Key components → Scale/phases → Risks → What we can do now vs later →
Expected outcome. Bold lead-in labels, ✅/❌ examples, "In one sentence:" TL;DRs, code blocks. Even
here: no em dashes, no filler.

**eod** — see the `eod-report` skill.

**cover-letter / application-form** — humbler by default. State a missing skill plainly (*"I haven't
worked with Java professionally"*) and offset with breadth, not bravado. **His own ventures stay
unnamed** in job applications — naming them reads as divided commitment; claim the experience
directly instead (*"I have real experience with payment systems"*). Employers get named; his
ventures don't.

**spoken pitch** — must not read like resume bullets. Not *"lideré"*, not *"hago ingeniería para"*.
He says *"monté"*, *"trabajo en"*, *"me encargo de"*. Facts stay, polish goes.

**prompt** — names the perspectives/agents he wants, states the problem precisely, iterates in plan
mode. The goal is closing the gap between the real problem and what the model understands, to cut
iterations. *(Thin — capture real samples into the corpus as they happen.)*

## PR text

Shorter, plainer, no walkthrough of the investigation, no arguing the change is correct. Comments
in the code itself are the `code-comments` skill.

## Mode B — writing to him

Same hard rules. Additionally: when extracting facts from him (gap-closing, seeding a system), he
prefers **short interactive rounds of concrete option-questions** over long free-text
questionnaires. Free text only for the final specifics dump.

## Anti-examples

- *"Additionally, this leverages a robust solution to ensure seamless integration."*
- *"Think of the gateway like a translator at the airport…"*
- Inflating a one-line "Yup, on it" into a paragraph.
- Em dashes for emphasis.
- Opening a review reply with "Good catch", or with "you're right".

## Related

Corpus and samples: `$CONTEXT_VAULT/_Framework/learning/corpus.md`. The loop that maintains this
skill: `style-learning` + `/learn`.
