---
name: e2e-testing
description: Use when writing, running or debugging end-to-end tests that drive the frontend app against a running API and a seeded test database, including the e2e track of a parallel cross-stack feature.
applies_to: [angular-app, express-api]
---

# Skill: E2E Testing

> One worktree, one port, one seeded database, one fictitious tenant. Test the business flow a user sees, with stable selectors and no sleeps.

## When this applies

- The `e2e` track of a cross-stack feature: it runs last, after `api` then the frontend apps merge, and plays the scenario pinned in the feature contract.
- Any e2e run in a repo, and any test that starts the Angular dev server and the Express API together.
- Debugging a flaky e2e test or a failure that only appears with real HTTP and a real database.
- These tests must pass the `test-audit` gate (what contract it protects, which regression fails it, why lower-level coverage misses it, whether it needs a seam, which CI job runs it).

Use the runner the repo has (Cypress or Playwright). Examples show both where the API differs.

## Rules

### 1. Give each worktree its own database, port and tenant
Parallel tracks never share state. Database `app_test_<slug>_<track>`, a port per worktree recorded where the work is dispatched, and a fictitious tenant `demo-store` (add `demo-outlet` when a test needs a second tenant).

✅ Do
```ts
// e2e env for the worktree of feature "transfers", track e2e
const db = `app_test_transfers_e2e`;
const apiPort = dispatchRow.apiPort;   // from the dispatch record, never a guessed default
const appPort = dispatchRow.appPort;
```
❌ Don't
```ts
const db = 'app_test';           // two tracks seed and wipe the same data
const baseUrl = 'http://localhost:4200'; // another worktree is already serving there
```

### 2. Seed through code, reset before each spec
A seed module builds the tenant, users per role, locations, items with batches, an account per currency and an exchange rate snapshot. Each spec starts from a known state. Fixtures are fictitious (`customer-data-protection`): no real names, tax ids, national ids, phones or amounts.

✅ Do
```ts
beforeEach(async () => {
  await resetDb(db);
  await seedTenant({ subdomain: 'demo-store', users: ['owner', 'cashier'], locations: ['warehouse', 'storefront'],
    items: [{ sku: 'DEMO-FLOUR-1KG', batches: [{ location: 'warehouse', qty: 24 }] }], rate: { rate: '0.92', source: 'FX_PROVIDER_USD_EUR' } });
});
```
❌ Don't
```ts
// spec depends on data a previous spec created, or on a copy of a real tenant's export
it('sells the product created in the previous test', () => { /* ... */ });
```

### 3. Never call destructive admin routes outside the test tenant
Routes that reset a tenant, wipe inventory, reverse or return an order, or remove a location are allowed only against the local seeded `demo-store` in the worktree's own database. Never against staging or production URLs.

✅ Do
```ts
await api.post('/admin/return-order', { orderId }); // api base = this worktree's apiPort
```
❌ Don't
```ts
await api.post('https://<staging-host>/api/admin/reset-tenant'); // wipes shared data
```

### 4. Select by role, label or `data-testid`, never by CSS structure
Prefer accessible roles and labels. Where those are ambiguous, use `data-testid`. Adding a `data-testid` touches app templates owned by another track: list each new id in the contract and get approval before adding it.

✅ Do
```ts
// Playwright
await page.getByRole('button', { name: 'Checkout' }).click();
await page.getByTestId('cart-total').waitFor();
// Cypress
cy.findByRole('button', { name: 'Checkout' }).click(); // if Testing Library is installed
cy.get('[data-testid="cart-total"]').should('be.visible');
```
❌ Don't
```ts
cy.get('div.col-md-6 > .card:nth-child(3) button.btn-primary').click(); // breaks on any Bootstrap layout change
```

### 5. Wait on state, never on time
Wait for a network response, a visible element or a socket-driven update. Fixed sleeps make tests slow on fast machines and flaky on slow ones.

✅ Do
```ts
// Playwright
await Promise.all([page.waitForResponse((r) => r.url().includes('/api/invoices') && r.ok()), submitBtn.click()]);
// Cypress
cy.intercept('POST', '**/api/invoices').as('create'); cy.get('[data-testid="create-invoice"]').click(); cy.wait('@create');
```
❌ Don't
```ts
cy.wait(3000);
await page.waitForTimeout(3000);
```

### 6. Test business flows, not pages
One spec per user outcome from the contract scenario: an order priced in one currency and paid in another, an end-of-day close with a shortage, a credit order creating a receivable then a partial payment, a stock transfer between locations. Assert the business result, including the side effects other modules show.

✅ Do
```ts
it('a credit order creates a receivable and decrements stock', async () => {
  await sellOnCredit({ sku: 'DEMO-FLOUR-1KG', qty: 2, customer: 'Demo Customer' });
  await expectReceivableBalance('Demo Customer', { amountMinor: 700, currency: 'USD' });
  await expectStock('DEMO-FLOUR-1KG', 'storefront', 22);
});
```
❌ Don't
```ts
it('inventory page loads', () => { cy.visit('/inventory'); cy.contains('Inventory'); }); // proves little
```

### 7. Log in through the API, test the login UI once
The login flow (including any handoff from a separate login host to the tenant's app) gets its own spec. Every other spec sets the session programmatically so it does not depend on the login screen. Work out the local equivalent of a tenant subdomain (hosts entry, header, or query).

✅ Do
```ts
beforeEach(() => loginAs('cashier', { tenant: 'demo-store' })); // calls the sign-in endpoint, stores the session as the app expects
```
❌ Don't
```ts
beforeEach(() => { cy.visit('/auth/login'); cy.get('#email').type(...); cy.get('#password').type(...); });
```

### 8. Stub third parties at the edge
Payment providers, chat widgets, analytics and partner APIs are stubbed or disabled in the e2e environment. Never hit a real payment provider; Stripe flows use test mode only, and webhook handling is tested at the API integration level.

✅ Do
```ts
await page.route('**/js.stripe.com/**', (r) => r.fulfill({ body: '' }));
cy.intercept('POST', '**/api/plans/pay-with-card', { fixture: 'plans/pay-ok.json' });
```
❌ Don't
```ts
// spec pays a plan through a live checkout and reads the result from the provider dashboard
```

### 9. Keep artifacts on failure only, and scrub them
Traces, videos and screenshots are kept for failures. They show only fictitious data because the seed is fictitious; never record against a real tenant.

✅ Do
```ts
// playwright.config: use: { trace: 'retain-on-failure', video: 'retain-on-failure' } (if Playwright)
// cypress.config: video: false, screenshotOnRunFailure: true (if Cypress)
```
❌ Don't
```ts
// recording a session on production to "reproduce" a customer bug
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Shared test database across tracks | Seeds collide, tests flake | `app_test_<slug>_<track>` |
| Hardcoded dev port | Hits another worktree's server | Port from the dispatch record |
| Fixed sleeps | Slow and flaky | Wait on response or element |
| Bootstrap class selectors | Break on markup changes | Role, label, approved `data-testid` |
| Specs that depend on order | One failure cascades | Reset and seed per spec |
| UI login in every spec | Slow, couples to one screen | Programmatic login |
| Real tenant data in seeds or recordings | Data exposure | `demo-store` fixtures |
| Destructive admin routes against shared envs | Destroys shared data | Local seeded tenant only |

## Review checklist

- [ ] Database, ports and tenant come from the worktree's dispatch record.
- [ ] Each spec resets and seeds; no order dependence.
- [ ] Selectors are role, label or an approved `data-testid` listed in the contract.
- [ ] No fixed sleeps.
- [ ] Specs assert business outcomes across modules (stock, balances, receivables and payables).
- [ ] Third parties are stubbed; no live payments.
- [ ] Destructive admin routes used only against the seeded local tenant.
- [ ] The spec passes the `test-audit` gate and names the CI job that runs it.

## Adapt to your repo

- The e2e runner (Cypress or Playwright) and its config file location, if any exists.
- How the app and API are started for e2e, and the scripts that do it.
- How the API is pointed at a database name (env var name).
- How the app is pointed at the API (environment file or proxy config).
- How the tenant subdomain is simulated locally.
- The existing seed or fixture tooling, if any.
- Whether `data-testid` or another test attribute is already in use.
- Whether Testing Library helpers are installed for the runner.
- The CI job that runs e2e, if any.
- How third-party scripts (Stripe.js, chat widgets, analytics) are disabled outside production.
