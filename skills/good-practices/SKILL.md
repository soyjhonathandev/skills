---
name: good-practices
description: Use on every change in a web app or API repo; the stack-agnostic baseline for naming, function size, error handling, constants, comments, commits, tests, secrets and customer data. Read it before the stack skills.
applies_to: [angular-app, express-api]
---

# Skill: Good Practices

> The baseline every change meets before the Angular or Express rules apply: clear names, small units, loud errors, no magic values, no secrets, no real customer data.

## When this applies

- Every implementation, review and refactor, on the frontend and the API.
- Read it before coding; reviewers cite its rule numbers.
- Stack rules build on it: `angular-good-practices`, `express-good-practices`. Domain facts live in the project's business-context notes.
- Team-practice skills (`code-comments`, `commit-creation`, `pr-creation`, `test-audit`, `customer-data-protection`, `decision-protocol`) own their topics; this skill points to them.

## Rules

### 1. Name things for the business, in the codebase's language
Use the domain noun the module already uses (`invoice`, `pendingAccount`, `inventoryBatch`). Keep one name per concept per side; do not mix `bill`, `invoice` and `receipt` for the same thing in new code. Domain terms already in the code stay, even in another language; new identifiers follow the existing convention.

✅ Do
```ts
function closeInvoice(invoiceId: string, lines: InvoiceLineDto[]): Promise<InvoiceCloseResult> { /* ... */ }
```
❌ Don't
```ts
function doIt(id: string, arr: any[]): Promise<any> { /* ... */ }
function closeBill(receiptId: string) { /* ... */ } // three vocabularies in one line
```

### 2. Keep functions small and single-purpose
A function validates, or computes, or persists, or maps. When a function needs a comment to separate its phases, split it.

✅ Do
```ts
const totals = computeOrderTotals(cart, rate);
await persistOrder(tenantId, cart, totals);
emitOrderCreated(tenantId, orderId);
```
❌ Don't
```ts
async function handleOrder(req, res) { /* 180 lines: validation, pricing, tax, stock, payment, receivables, socket, response */ }
```

### 3. Never swallow an error
Catch only to add context, translate to a known error, or recover with a real fallback. Otherwise let it propagate to the central handler (API) or the error interceptor (app).

✅ Do
```ts
try {
  await extraction.parseInvoice(file);
} catch (err) {
  throw new HttpError(422, 'INVOICE_EXTRACTION_FAILED', 'Could not read the supplier invoice', undefined, { cause: err });
}
```
❌ Don't
```ts
try { await bank.transfer(dto); } catch (e) { console.log(e); } // the user sees success, the money did not move
```

### 4. No magic values: rates, percentages, limits and ids are named
Tax rates (sales tax, VAT), exchange rates, commission percentages, page sizes, timeouts and plan limits come from config or a named constant with a source. Rates and taxes are never constants in code: see `money-and-currency`.

✅ Do
```ts
const MAX_PAGE_SIZE = 100;
const salesTax = await taxConfig.salesTaxFor(tenantId, date); // rate from config, never inline
```
❌ Don't
```ts
if (items.length > 37) { /* ... */ }
total = total * 1.03;
```

### 5. Delete dead code; do not comment it out
Git keeps history. Commented blocks, unused exports, feature flags that are always on, and unreachable branches make the next reader guess.

✅ Do
```ts
export function joinBatches(a: InventoryBatch, b: InventoryBatch): InventoryBatch { /* current logic */ }
```
❌ Don't
```ts
// export function joinBatchesOld(a, b) {
//   ...
// }
```

### 6. Comment only what the code cannot say
Follow `code-comments`: default to no comment. Keep a comment only for a runtime footgun, why the obvious approach was not taken, a unit or contract the types do not carry, or an invariant. Never an issue number, never narration of the thinking process.

✅ Do
```ts
amountMinor: number; // cents; the wire format has no decimals
```
❌ Don't
```ts
// see #412
// first I tried with reduce but it failed so now we loop
// loop over the batches
for (const b of batches) { /* ... */ }
```

### 7. Validate at the boundary, trust inside
Input is validated once where it enters (Express validator, Angular form validators for UX). Services assume typed, validated input; the database schema is the last line, not the first.

✅ Do
```ts
router.post('/accounts/:id/payments', validate(CreatePaymentDto), controller.addPayment);
```
❌ Don't
```ts
async function addPayment(dto) { if (!dto || typeof dto.amountMinor !== 'number' || ...) { /* repeated in every layer */ } }
```

### 8. No secrets and no real customer data, anywhere
Keys, tokens and connection strings live in environment configuration and are referenced by name. Fixtures, logs, test names, screenshots and prompts use fictitious data (`demo-store`, `Demo Customer`); never a real subdomain, customer, tax id, national id, phone or amount (`customer-data-protection`).

✅ Do
```ts
const stripe = new Stripe(config.stripeSecretKey); // loaded from the environment
const customer = buildCustomer({ name: 'Demo Customer', taxId: '00-0000000' });
```
❌ Don't
```ts
const stripe = new Stripe('<a key pasted here>');
logger.info({ body: req.body }, 'new customer'); // logs a real phone and national id
```

### 9. One concern per commit, gitmoji titles
Follow `commit-creation`: `:sparkles: scope: title`, at most 60 characters rendered, one concern each. A refactor and a behavior change are two commits.

✅ Do
```text
:seedling: inventory: extract batch split into a service
:bug: inventory: keep location when splitting a batch
```
❌ Don't
```text
fix stuff + refactor + update deps
```

### 10. Add tests that earn their place
Follow `test-audit`: answer the five authoring questions before writing a test. The retention bar always keeps tests for auth, tenant isolation, money math, payments, inventory decrement, receivable and payable balances, and migrations.

✅ Do
```ts
it('splitting a batch keeps total quantity per location', () => { /* protects inventory/splitBatch */ });
```
❌ Don't
```ts
it('should create', () => { expect(component).toBeTruthy(); }); // protects nothing
```

### 11. Decide what is reversible, ask what is not
Follow `decision-protocol`. Decide naming, local structure and test shape yourself. Ask before changing a contract, a shared file owned by another track, a money or tax rule, a migration, or anything touching destructive admin endpoints. Present choices as `[A]/[B]` with the recommendation first.

✅ Do
```text
Decision: sales tax on mixed-currency payments.
[A] (recommended) apply per foreign-currency payment line, rate from config
[B] apply on the order total
```
❌ Don't
```text
// picked a tax rule silently because the ticket did not say
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `any` and one-letter names | Readers and the compiler lose intent | Domain names and types |
| `catch (e) {}` or log-and-continue | Silent data loss, money mismatches | Propagate or translate |
| Inline percentages and rates | Wrong after the next tax change | Config with source and date |
| Commented-out code | Noise, stale logic | Delete; git has it |
| Narrating comments and issue refs | Rot, belong in the PR | `code-comments` rules |
| Mixed-concern commits | Hard to review and revert | One concern per commit |
| Real customer data in fixtures | Privacy breach | Fictitious fixtures |
| Guessing on business rules | Wrong money or stock | Ask the domain expert or the developer |

## Review checklist

- [ ] Names match the module's domain vocabulary.
- [ ] No function mixes validation, computation, persistence and I/O.
- [ ] No swallowed errors.
- [ ] No magic numbers, rates or percentages.
- [ ] No dead or commented-out code.
- [ ] Comments pass the `code-comments` rules (`git diff --unified=0 | grep -E "^\+\s*(//|\*|/\*)"`).
- [ ] Input validated once at the boundary.
- [ ] No secret values, no real customer data.
- [ ] Commits are single-concern with gitmoji titles.
- [ ] New tests pass the `test-audit` gate.
- [ ] Irreversible choices were asked, not assumed.

## Adapt to your repo

- The identifier language convention (English, another language, or mixed by module).
- Lint and format tools and their configs (ESLint, Prettier, TSLint on older Angular setups).
- `strict` settings in each `tsconfig`.
- Where configuration and environment values are loaded on the API.
- The repo's PR template and CI gates.
- The test runners in use (unit, integration).
