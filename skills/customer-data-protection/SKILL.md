---
name: customer-data-protection
description: No real tenant, customer, tax id, national id, phone, bank account or business figure in notes, fixtures, tests, logs, prompts, PRs or screenshots; fictitious tenants (demo-store) only, checked with reviewer greps. Load whenever you write fixtures, seeds, tests, log lines, notes, issues or PRs, or handle a support case with real data in it.
---

# Skill: Customer Data Protection

> Every tenant is a real business, and its data is its customers' data. Nothing that identifies a
> tenant, a customer or a person, and no figure tied to a real business, goes into notes, fixtures,
> tests, seeds, logs, agent prompts, issues, PRs or screenshots. Write `<tenant>` in prose and use
> fictitious tenants such as `demo-store` everywhere else. The reviewer greps below run on every change.

## When this applies

Every agent and every developer, in every repo and notes folder: writing context notes, task briefs,
contracts, fixtures, seed scripts, tests, log statements, issues, PR bodies and review replies, and
whenever a support case or bug report arrives with real data in it. It pairs with `secret-redaction`
(credentials) and `multi-tenancy` (how code scopes queries).

## What counts as customer data

- Tenant subdomains (`<tenant>.your-app.com` with a real name), business names, owner names.
- Government identifiers: tax ids, national ids, in whatever format your country uses.
- Phone numbers, including mobile payment details (phone, id number and bank code).
- Bank account numbers, card data, customer records at payment providers.
- Customer names, emails, addresses; orders, receivable and payable balances, inventory counts and
  end-of-day close totals of a real business.

## Rules

1. **Fixtures are fictitious, and look it.** Tenants `demo-store`, `demo-outlet` (a second tenant
   for isolation tests). Business `Demo Store Ltd.`, tax id and national id all zeros in your country's
   format, phone all zeros after the area code, email at `example.com`, account number all zeros. If a
   validator needs a check digit, the fixture factory computes it from the zeros.
   - ✅ Do: `createCustomer({ tenant: 'demo-store', name: 'Demo Customer', taxId: '00-0000000' })`
   - ❌ Don't: copy a customer row from production "because it had the edge case". Rebuild the edge
     case with fake values.

2. **Prose says `<tenant>`.** Notes, briefs, contracts, issues and PRs never name a real tenant or its
   subdomain.
   - ✅ Do: "On `<tenant>.your-app.com` the invoice list shows the previous day's totals."
   - ❌ Don't: name the store where the bug was reported, or paste its subdomain.

3. **Amounts tied to a real business never leave it.** Use round fictitious amounts that make the
   arithmetic easy to check.
   - ✅ Do: "an order of $10.00 at a fictitious rate of 100 units per dollar is 1,000.00, plus sales tax
     on the dollar part."
   - ❌ Don't: "the tenant's end-of-day close was off by 18,432.17 yesterday."

4. **Reproduce on a demo tenant, not with the data.** A support case becomes a reproduction on
   `demo-store` with the same shape (currencies, payment methods, batch layout), never with the
   customer's records.
   - ✅ Do: "Mixed-currency order, two payments, one partial payment on a receivable, reproduced on demo-store."
   - ❌ Don't: attach the tenant's exported spreadsheet to the issue.

5. **Production data never becomes test data.** No dumps, exports or copies of a production database
   into a local or test database. Test databases are seeded from fixtures.
   - ✅ Do: seed with the repo's fixture factories.
   - ❌ Don't: run a restore of a production dump to debug locally.

6. **Screenshots only from demo tenants.** A screenshot of a real tenant's screen never goes into a
   note, issue, PR or chat, even cropped or blurred.
   - ✅ Do: take the PR screenshot on `demo-store`.
   - ❌ Don't: screenshot a real dashboard and blur the name.

7. **Prompts are a publication.** Anything pasted into an agent prompt, task brief or Agent Team
   question follows the same rules. Strip identifiers before handing a log or record to a subagent.
   - ✅ Do: give the agent the error, the route and the fixture that reproduces it.
   - ❌ Don't: paste a customer record "so the agent understands the bug".

8. **Logs carry ids, not people.** Logs may carry the internal tenant id and request id. Never a tax id,
   national id, phone, customer name, bank account or per-customer amount. `logging-observability`
   owns the redaction mechanism.
   - ✅ Do: `logger.info({ tenantId, orderId }, 'order closed')`
   - ❌ Don't: `logger.info('order closed for ' + customer.name + ' ' + customer.taxId)`

9. **Destructive endpoints only on demo tenants.** Destructive admin routes (reset a tenant, wipe
   inventory, reverse or return an order, remove a location) run only against a local or disposable
   test tenant.
   - ✅ Do: call the inventory reset on `demo-store` in a local stack.
   - ❌ Don't: point a script at a real tenant "to reset the test data".

## Reviewer greps

Run on the notes folder, or on a repo worktree before a PR (also `git diff <trunk>... | command grep -nE '<pattern>'`).
Zero-pattern fixture values are filtered out. Your company's own public contact addresses are company
facts, not customer data.

```bash
cd <repo or notes root> || exit 1
g() { command grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=customer-data-protection "$@" .; }
# Tenant subdomains other than the product hosts and demo tenants (set DOMAIN and the allowed hosts)
DOMAIN='your-app\.com'
g -o "[a-z0-9-]+\.$DOMAIN" | command grep -vE ":(www|api|login|demo-[a-z-]+)\.$DOMAIN\$"
# Tax ids and national ids: replace ID_PATTERN with your country's formats; zero-pattern values are dropped
ID_PATTERN='<your id regex>'
g -o "$ID_PATTERN" | command grep -vE '^[^:]+:[0-9]+:[A-Za-z-]*[0 .-]+$'
# Phone numbers in international form, except all-zero fixtures
g -o '\+[1-9][0-9 -]{7,16}[0-9]' | command grep -vE '\+[0-9]{1,3}[ -]?[0 -]+$'
# Long digit runs (bank accounts, card numbers), with or without separators
g -o '(^|[^0-9])[0-9]{4}([ -]?[0-9]{4}){2,4}([^0-9]|$)' | command grep -vE ':[^0-9]*[0 -]+[^0-9]*$'
# Real-looking emails (example.com and example.org are reserved for fixtures)
g -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' | command grep -vE '@(example\.(com|org)|users\.noreply\.github\.com)$'
# Images, PDFs and dumps added by the change: open each one
git diff --name-only --diff-filter=A <trunk>... | command grep -iE '\.(png|jpe?g|gif|webp|heic|pdf|bson|gz|archive|xlsx|csv)$'
```

## Checklist (for reviewers)

- [ ] Every grep above prints nothing, or only hits you confirmed are fictitious.
- [ ] Fixtures and seeds use `demo-*` tenants and zero-pattern identifiers.
- [ ] No real tenant, business, customer or person named in prose, code, tests or PR text.
- [ ] No amount, balance or count from a real business.
- [ ] Every added image or PDF was opened and shows a demo tenant only.
- [ ] No production dump, export or copy is referenced or committed.
- [ ] New log lines carry ids, not identifiers or per-customer amounts.
- [ ] No destructive admin route targets anything but a local or disposable test tenant.

## Adapt to your repo

- Your product domain and the hosts that are not tenants (www, api, login), for the subdomain grep.
- The tax id and national id formats of the countries you serve, for `ID_PATTERN` and the fixtures.
- The local phone and bank account formats, if the international-form greps miss them.
- Your demo tenant names and fixture factories.
- The destructive admin routes in your API.

## Notes

A leaked identifier is reported to the developer at once and removed from history by whoever owns the
repo; deleting the line in a later commit leaves it in git. The same restraint for credentials lives in
`secret-redaction`.
