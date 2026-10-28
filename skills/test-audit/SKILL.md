---
name: test-audit
description: The authoring gate for every new or changed test (five questions, junk patterns, a retention bar) and the audit mode for sweeping low-value, implementation-coupled, duplicated or unrun tests. Load before writing, reviewing or removing a test.
---

# Skill: Test Audit

> Two modes, one bar. Authoring mode gates each new or changed test at write time. Audit mode sweeps
> existing tests that re-assert the source, duplicate stronger proof, couple to implementation or never
> run in CI. The goal is confidence in what matters to a tenant (money, stock, tenant isolation),
> not a test count.

## When this applies

Whenever a test is written, changed, reviewed or removed: Angular unit and component tests, Express
integration tests (supertest with mongodb-memory-server), and e2e scenarios. Load it before writing a
test; reviewers check it.

## Rules

1. **Pass the five-question gate before writing a test.** A missing answer means no test.
   1. What observable behavior, invariant or contract does it protect?
   2. What credible regression makes it fail?
   3. Why does existing coverage not catch that already? (One primary test owns each contract, at the
      strongest boundary; extend it before adding a near-duplicate.)
   4. Does it need a production seam (an export, flag or hook no production caller needs)? Then test
      at the real boundary instead.
   5. Which CI job runs it? None means it protects nothing until the workflow runs it.
   - ✅ Do: "Protects: a partial payment on a payable lowers the balance by the paid amount in its
     currency. Fails if: the payment is converted at the wrong exchange rate. Not covered: only the
     full-payment path is tested. Seam: none, through the HTTP route. CI: the api test job."
   - ❌ Don't: add `it('should create')` because the CLI generated it.

2. **In an agent session, answers first, test second.** Give the developer the five answers and write
   the test after they agree. List each new test under `## Tests` in the PR with what it protects and
   the CI job that runs it.
   - ✅ Do: "## Tests: `<spec>` protects tenant isolation on `GET /api/pending-accounts`; runs in <job>."
   - ❌ Don't: open a PR with eleven new spec files and no word on why.

3. **Reject junk patterns.** A new test matching one fails the gate unless the retention bar names the
   contract it guards alone:
   - no assertion, or a committed `xit`, `xdescribe`, `fit`, `.only`, `.skip`, `pending()`;
   - the generated `should create` / `toBeTruthy()` test with nothing else in it;
   - self-comparisons, copied fixtures, export or inventory lists, greps of source strings;
   - expected values produced by the helper under test (`expect(toEur(x)).toEqual(toEur(x))`);
   - mocks that implement the behavior being asserted (a stubbed Mongoose model that returns
     pre-filtered rows, then a test that the filter works);
   - private methods reached through `component['method']` when the public path already covers them;
   - markup snapshots, CSS class or DOM-structure assertions, trivial renders;
   - fixed sleeps (`tick(5000)` with no timer under test, `cy.wait(2000)`, `waitForTimeout`) instead of
     waiting on a real condition;
   - a tenant-isolation test with only one tenant in the database (it passes no matter what);
   - money asserted with `toBeCloseTo`, which hides the rounding rule the test should pin;
   - names that promise more than the test exercises.
   - ✅ Do: assert the exact converted amount in minor units for a fictitious rate.
   - ❌ Don't: assert that the total "is close to" 1000.

4. **Keep what clears the retention bar.** A test stays when it alone enforces a contract others
   depend on:
   - auth and session gating, roles and permissions;
   - tenant isolation: one tenant can never read or write another's data (two `demo-*` tenants);
   - money math: currency conversion at the stored exchange rate, sales tax, rounding, totals in minor units;
   - payments: methods, mixed-currency payments, bank and mobile transfers, Stripe webhook verification;
   - inventory decrement: an order, return or shrinkage moves stock by exactly its quantity, per batch;
   - receivable and payable balances: partial payments, full payment, reversal, balance per currency;
   - migrations: up on a seeded test database leaves the documents the schema expects;
   - critical flows: sell, close the day, see the result in the reports;
   - regressions for bugs that already came back once, and edge-heavy logic hard to check by hand.
   Static or slow is not a reason to delete. A retained test failing on the baseline is a possible
   product bug: fix the owner, don't delete the test.
   - ✅ Do: keep the slow e2e that sells on `demo-store` and checks the end-of-day close totals.
   - ❌ Don't: delete it because it takes two minutes.

5. **A first-time bug fix gets no regression test**, unless the same thing broke before (link the
   earlier issue in the PR) or the fix sits on a retention-bar contract. A regression test must fail
   on the pre-fix code for the intended reason.
   - ✅ Do: a receivable balance fix gets a test, because receivable and payable balances are on the bar.
   - ❌ Don't: a test for a label typo.

6. **Route every test to a CI job.** Know which job runs which path from the repo's workflows.
   - ✅ Do: name the job and the path filter that picks the file up.
   - ❌ Don't: add an e2e spec in a folder no workflow runs.

7. **Audit read-only first, evidence before edits.** Before judging a test, read it whole, its
   production owner, callers, overlapping tests, CI routing and history (`git log`, the PR that added
   it). Record per candidate: name and location, what failure it can detect, whether CI runs it, the
   stronger remaining proof, and the code its removal unlocks. A retained test no job runs gets wired
   in, not deleted. Removals go in their own PR, never mixed into a feature or fix.
   - ✅ Do: a `:seedling: tests:` PR that removes five generated `should create` specs, with the evidence.
   - ❌ Don't: delete tests inside a feature PR.

8. **Tests use fictitious data and their own database.** `demo-store` fixtures, zero-pattern
   identifiers, and the worktree's own test database (`customer-data-protection`).
   - ✅ Do: seed two demo tenants for an isolation test.
   - ❌ Don't: load a real tenant's export as a fixture.

## Validation

1. Run the smallest owner tests (the repo's test commands, usually in `AGENTS.md` or the README).
2. Confirm the CI job and path filter that pick the file up.
3. `git diff --check`, then report production versus test lines from `git diff --numstat`.

## Checklist (for reviewers)

- [ ] Each new test has five answers in the PR under `## Tests`.
- [ ] No new test matches a junk pattern unless the retention bar justifies it.
- [ ] Isolation tests use two tenants; money tests assert exact minor units.
- [ ] Every new test is run by a named CI job.
- [ ] Bug-fix regression tests fail on the pre-fix code.
- [ ] Test removals come with per-test evidence and sit in their own PR.

## Adapt to your repo

- The CI jobs and the paths each one runs.
- The test commands for each runner.
- Which contracts in your domain belong on the retention bar beyond the list above.

## Notes

Method adapted from the test-audit skill in the openclaw project (MIT License).
