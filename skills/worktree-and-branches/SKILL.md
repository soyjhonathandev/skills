---
name: worktree-and-branches
description: Branches are <prefix>/<topic> (prefix from git config branch.prefix, else the developer's existing branches, else ask), each in a sibling worktree <repo>-<label>; the primary checkout stays on trunk and is the only canonical source for docs and context. Load before creating a branch or worktree, and whenever a repo is read to write docs about it.
---

# Skill: Worktree and Branches

> Every change happens on a `<prefix>/<topic>` branch inside its own sibling worktree `../<repo>-<label>`. The
> primary checkout `<parent>/<repo>` stays on trunk, is never edited, and is the only place canonical docs and
> context are derived from. Feature worktrees are in-flight work: tracked, never treated as truth. Trunk is per
> repo and confirmed with the developer.

## When this applies

Whenever work is handed to a repo (a new task, `/team` execution, `/parallel` tracks), and whenever a repo is
read to write docs or context notes about it.

## Rules

1. **Resolve the prefix in order: config, history, ask.** `branch.prefix` is a team convention key in git
   config, not a built-in git setting.
   - ✅ Do: read `git config branch.prefix`; if empty, take the most common prefix of the developer's own
     branches (command below); if none, ask once and offer `git config --global branch.prefix <prefix>`.
   - ❌ Don't: invent a prefix, use `feature/` by default, or reuse another developer's prefix.

2. **Topic is short English kebab-case.** Five words or fewer, saying what the branch does. `fix-` in front for
   bug fixes. A track of a parallel feature always adds its track to the feature slug: `<prefix>/<slug>-<track>`
   (`<prefix>/cash-close-api`).
   - ✅ Do: `<prefix>/cash-close-rounding`, `<prefix>/fix-mixed-payment-tax`
   - ❌ Don't: `<prefix>/CashClose_v2`, `<prefix>/stuff`, `fix-tax` (no prefix)

3. **One branch, one sibling worktree.** The worktree lives next to the primary checkout and is named
   `<repo>-<label>`. Feature worktrees use the feature slug as label (`api-cash-close`), plus `-<track>` when
   two tracks share a repo (`app-cash-close-e2e`), matching the session name (the `parallel-sessions` skill).
   - ✅ Do: `git -C <parent>/api worktree add ../api-cash-close -b <prefix>/cash-close-api origin/<trunk>`
   - ❌ Don't: `git checkout -b` inside the primary checkout, or put two branches in one worktree.

4. **Never work in the primary checkout.** `<parent>/<repo>` stays on trunk and only receives
   `git pull --ff-only`. No edits, no commits, no dev server for feature work.
   - ✅ Do: run the feature's dev server from `<parent>/app-cash-close`.
   - ❌ Don't: "quickly fix it on trunk" in the primary checkout.

5. **Trunk is a per-repo fact.** Read the remote default branch, confirm it with the developer, and record it
   where the repo's agents read it (`AGENTS.md` or `CLAUDE.md`).
   - ✅ Do: `git -C <parent>/api symbolic-ref --short refs/remotes/origin/HEAD`, then record the answer.
   - ❌ Don't: assume `main` (or `master`, or `staging`) and write it down.

6. **A pre-commit hook guards trunk where the repo has one.** It refuses commits on trunk and protected
   branches. Nobody bypasses it.
   - ✅ Do: on a refusal, create the branch and worktree, then commit there.
   - ❌ Don't: `git commit --no-verify` on trunk.

7. **Canonical docs come from the primary checkout at trunk.** A note that describes a repo cites the trunk
   commit it was written from. A feature worktree is unmerged and may be abandoned.
   - ✅ Do: stamp the source revision from `git -C <parent>/api rev-parse --short <trunk>`.
   - ❌ Don't: document the new cash close behavior from `<parent>/api-cash-close` before it merges.

8. **Track in-flight work from git.** A list of in-flight work (worktree, branch, topic, prunable) is built
   from `git worktree list`, not from directory names.
   - ✅ Do: confirm `api-tax-fix` is on `<prefix>/fix-mixed-payment-tax` with `--porcelain`.
   - ❌ Don't: guess the branch from the folder label.

9. **Prunable means remove.** After merge, remove the worktree and delete the merged branch.
   - ✅ Do: `git -C <parent>/api worktree remove ../api-cash-close && git -C <parent>/api worktree prune`
   - ❌ Don't: list a `prunable` worktree as live work, or delete one that holds unmerged commits without asking
     (the `decision-protocol` skill).

## Commands

```bash
r=<parent>/api                    # the primary checkout of the repo
git -C "$r" config branch.prefix  # rule 1, step 1
me=$(git -C "$r" config user.email)
git -C "$r" for-each-ref --format='%(authoremail) %(refname:lstrip=3)' refs/remotes/origin \
  | grep -F "<$me>" | awk '{print $2}' | grep / | cut -d/ -f1 \
  | sort | uniq -c | sort -rn | head -1      # rule 1, step 2: most used prefix
git -C "$r" worktree list                   # first row is the primary checkout
git -C "$r" worktree list --porcelain       # branch and prunable per worktree
git -C "$r" rev-parse --abbrev-ref HEAD     # must print trunk
git -C "$r" status --porcelain              # must print nothing in the primary checkout
```

## Checklist (for reviewers)

- [ ] Branch matches `<prefix>/<kebab-topic>`, with the prefix resolved by rule 1.
- [ ] `git -C <parent>/<repo> worktree list` shows the branch in a sibling `<repo>-<label>` worktree.
- [ ] The primary checkout is on trunk with a clean `git status --porcelain`.
- [ ] No commit landed on trunk; no `--no-verify` in the session.
- [ ] Trunk was confirmed by the developer, not assumed.
- [ ] Docs stamp their source revision from trunk of the primary checkout, never a feature branch.
- [ ] The in-flight list comes from `git worktree list` and excludes prunable worktrees.

## Notes

Worktrees let many branches be checked out at once, which is what parallel tracks need (the
`parallel-sessions` skill). The price is discipline about which copy is canonical: one primary checkout on
trunk, everything else in flight.
