---
name: decision-protocol
description: When an agent decides alone and when it asks the developer, and how to present a decision point ([A]/[B] options, recommendation first, one question at a time). Load in any session that plans or implements.
---

# Skill: Decision Protocol

> The developer decides direction; agents execute. An agent decides alone when the answer is derivable
> from source, config, git or an existing convention and the step is reversible and in scope. It asks
> when the work could go two materially different ways, when scope or cost grows, when the step is
> destructive, or when a business rule is unknown. A question arrives as a decision point: the
> question, `[A]` with the recommendation, `[B]`, and the trade-off of each in one line.

## When this applies

Every agent that plans or implements, at every fork during planning, dispatch and execution. A
contract or plan that already pins the answer settles the fork: follow it.

## Rules

1. **Decide alone when the answer is derivable.** Source, config, git state, the contract or an
   established convention answers it, and the step is reversible and inside the stated scope.
   - ✅ Do: name a new API route in kebab-case English because `api-design` says so.
   - ❌ Don't: ask the developer whether to use `takeUntil` in an Angular component.

2. **Ask when interpretations diverge.** Two valid readings of the request lead to different work.
   - ✅ Do: "Does 'fix the invoice total' mean the rounding on the converted total, or the missing
     bank transfer payment line?"
   - ❌ Don't: pick one reading and build it.

3. **Ask when scope or cost grows.** New repos, new collections, new shared files, an Agent Team
   (about 3 to 4 times one session), more parallel tracks than planned, any paid service.
   - ✅ Do: "This also needs a migration on the orders collection, outside the task. Add a `migration` track?"
   - ❌ Don't: add the migration track and tell the developer afterwards.

4. **Ask before anything destructive.** Removing a worktree with unmerged commits, deleting branches,
   force pushes, data migrations on a shared database, any destructive admin route (reset a tenant,
   wipe inventory, reverse an order) even on a test tenant that someone else may be using.
   - ✅ Do: "`api-sales-tax` has 3 unmerged commits. Remove it anyway?"
   - ❌ Don't: `git worktree remove --force` because the dispatch record says `done`.

5. **Ask when a business rule is unknown. Never guess money.** When sales tax applies and at what rate,
   how converted amounts round, which exchange rate applies to a partial payment on a receivable: if no
   source states it, it is a question, recorded as `[PENDING]`.
   - ✅ Do: "The docs say sales tax applies 'when it corresponds'. Which payment methods trigger it?"
   - ❌ Don't: hardcode 3% because one blog post used it as an example.

6. **Ask when a rule would break.** A team skill, a contract invariant or a parallel-safety rule would
   have to be bent to proceed.
   - ✅ Do: "Both tracks need `app.module.ts`. Give it to the `app` track and route the other change through it?"
   - ❌ Don't: let both tracks edit it and merge carefully.

7. **Present a decision point in this shape.** One question at a time, recommendation first, the
   trade-off in one line each, then wait. The ambiguity check at the start of a plan is the exception:
   all clarifying questions go in one message.
   - ✅ Do:
     ```
     Where does the exchange rate snapshot live for an order paid in two currencies?
     [A] On each payment (recommended): an order paid in two moments keeps the rate of each payment.
     [B] On the order: one rate per order, simpler reports, wrong if payments span a rate change.
     ```
   - ❌ Don't: a free-text essay ending in "what do you think?", or options without a recommendation.

8. **Ask direction, not chores.** Questions are about what to build and what to risk. Anything the
   agent can find out with a command, it finds out.
   - ✅ Do: run `git worktree list` instead of asking which worktrees exist.
   - ❌ Don't: "Which port should the api use?" when the dispatch record allocates ports.

9. **Record the answer.** A decision that shapes the work goes into the contract or the plan before
   execution, so later agents do not reopen it.
   - ✅ Do: add "rate snapshot per payment, decided [A]" to the contract's decisions.
   - ❌ Don't: keep it only in the chat.

## Checklist (for reviewers)

- [ ] Every fork decided alone is backed by a source, the contract or a convention.
- [ ] Every destructive step, scope growth and cost jump was asked first, and the answer is recorded.
- [ ] No money or tax rule was guessed; unknowns are `[PENDING]`.
- [ ] Decision points used `[A]`/`[B]`, recommendation first, one question at a time.
- [ ] No question asked something a command could answer.

## Notes

`[A]`/`[B]` are the only option labels for decision points.
