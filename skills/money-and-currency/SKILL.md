---
name: money-and-currency
description: Use when code stores, computes, converts, rounds, displays or reports a monetary amount, uses an FX rate, applies a tax such as sales tax or VAT, or touches cash reconciliation, receivable or payable balances, or exchange gains and losses.
applies_to: [angular-app, express-api]
---

# Skill: Money and Currency

> Money is an exact amount plus a currency plus the rate used at that moment. Never a float, never a hardcoded tax, never two currencies summed into one balance.

## When this applies

- Orders, payment lines and change given, extra charges and discounts.
- Cash registers and end-of-day reconciliation (opening balances per account, counted totals, surplus or shortage).
- Receivables and payables, and partial payments against them.
- Account deposits, withdrawals and transfers; fixed and variable expenses; inventory cost.
- FX rates and exchange gain or loss reports.
- Subscription plans and payment provider charges; reports and xlsx/PDF exports that print amounts.
- Any review that touches money. Business facts (which rates, which taxes, which currencies) live in the project's business-context notes.

## Rules

### 1. Never use JS floats for money
`0.1 + 0.2 !== 0.3`, and an amount times a rate drifts by cents across a day of orders. Store integer minor units (`amountMinor`) or Decimal128. The examples use minor units.

✅ Do
```ts
interface Money { amountMinor: number; currency: 'USD' | 'EUR'; } // integer cents
const lineTotal: Money = { amountMinor: unitPriceMinor * qty, currency: 'USD' };
```
❌ Don't
```ts
const total = items.reduce((s, i) => s + i.price * i.qty, 0); // 12.299999999999999
order.total = parseFloat(form.value.total);
```

### 2. Store the currency with every amount
An amount without a currency is ambiguous in a business that takes more than one. Never infer the currency from the field name or the tenant default.

✅ Do
```ts
const PaymentLineSchema = new Schema({
  method: { type: String, required: true },          // cash, card, bank transfer
  amountMinor: { type: Number, required: true, validate: Number.isInteger },
  currency: { type: String, enum: ['USD', 'EUR'], required: true },
});
```
❌ Don't
```ts
const PaymentLineSchema = new Schema({ amountUsd: Number, amountEur: Number }); // which one was paid?
```

### 3. Snapshot the rate on each transaction
An order, payment, transfer or expense stores the rate it used: value, source and date. Later rate changes must never rewrite history; reports and FX results read the snapshot.

✅ Do
```ts
const RateSnapshotSchema = new Schema({
  rate: { type: Schema.Types.Decimal128, required: true }, // quote currency per 1 unit of base currency
  source: { type: String, enum: ['CENTRAL_BANK', 'MARKET', 'custom'], required: true },
  date: { type: Date, required: true },
}, { _id: false });

order.rate = await rates.snapshotFor(req.tenant.id, cart.rateSource);
```
❌ Don't
```ts
const totalEur = order.totalUsd * (await getTodayRate()); // computed at read time, history changes with the rate
```

### 4. Convert in one module with one explicit rounding rule
Conversion and rounding live in a single money module used by both API and app (or mirrored exactly). Pick the rounding mode and the point where it happens once, and write it down; never round ad hoc.

✅ Do
```ts
// money module: the only place that converts
export function toEur(usd: Money, snap: RateSnapshot): Money {
  const raw = new Decimal(usd.amountMinor).times(snap.rate.toString());
  return { amountMinor: roundMinor(raw), currency: 'EUR' }; // one rounding mode (half-up or half-even)
}
```
❌ Don't
```ts
const eur = Math.round(usd * rate * 100) / 100;   // in a component
const eur2 = (usd * rate).toFixed(2);             // in a service, different result
```

### 5. Never hardcode tax rates
Sales tax, VAT and any transaction tax change by law and may apply only to some payments. Read the rate and its trigger rules from one configured source of truth with an effective date; the formula receives them as inputs.

✅ Do
```ts
const tax = await taxConfig.transactionTaxFor(req.tenant.id, order.date); // { rateBps, appliesTo }
const taxLines = order.payments.filter((p) => tax.appliesTo(p)).map((p) => taxLine(p, tax.rateBps));
```
❌ Don't
```ts
if (payment.currency === 'EUR') total += payment.amount * 0.03; // magic rate and guessed trigger
```

### 6. Settle and report per currency, never as one mixed balance
Each currency is reconciled separately in a mixed payment, in a cash reconciliation and in an account balance. A converted "equivalent" total is a derived view labeled with its rate, never a stored balance.

✅ Do
```ts
interface CashCloseLine { accountId: string; currency: 'USD' | 'EUR'; expectedMinor: number; countedMinor: number; differenceMinor: number; } // + surplus, - shortage
```
❌ Don't
```ts
register.balance = cashUsd * rate + cashEur; // a cash drawer cannot hold this number
```

### 7. Move money atomically
An order that decrements inventory, credits an account and opens a receivable, or a transfer between accounts, runs in one MongoDB transaction. Half-applied money moves are the hardest bugs to repair. See `mongodb-mongoose`.

✅ Do
```ts
await mongoose.connection.transaction(async (session) => {
  await Account.updateOne({ _id: from }, { $inc: { balanceMinor: -amt } }, { session, tenantId });
  await Account.updateOne({ _id: to }, { $inc: { balanceMinor: converted } }, { session, tenantId });
  await AccountMovement.create([{ kind: 'transfer', from, to, amt, converted, rate: snap }], { session });
});
```
❌ Don't
```ts
await Account.updateOne({ _id: from }, { $inc: { balanceMinor: -amt } });
await Account.updateOne({ _id: to }, { $inc: { balanceMinor: converted } }); // crash here loses money
```

### 8. Format for display only at the edge, per currency
Templates format with one pipe; the API returns numbers plus currency, never preformatted strings. Each currency has its own symbol and locale grouping (`€1.234,56` in a European locale, `$1,234.56` in en-US); decide them once.

✅ Do
```ts
@Pipe({ name: 'money' })
export class MoneyPipe implements PipeTransform {
  transform(m: Money | null): string {
    if (!m) return '';
    return formatMoney(m); // one formatter; per-currency symbol and locale
  }
}
// template: <td>{{ line.total | money }}</td>
```
❌ Don't
```ts
// template: <td>€ {{ line.totalEur.toFixed(2) }}</td>
res.json({ total: `$${total.toFixed(2)}` }); // string the app cannot add
```

### 9. Report exchange gain or loss from snapshots
Exchange gain or loss (a receivable collected or a payable paid at a different rate than booked, foreign-currency balances held while the rate moves) is computed from stored snapshots. Never recompute past rates from today's rate.

✅ Do
```ts
const diffMinor = toEur(payment.usd, payment.rate).amountMinor - toEur(payment.usd, receivable.rate).amountMinor;
```
❌ Don't
```ts
const diff = receivable.amountUsd * todayRate - receivable.amountEur; // ignores the rate it was booked at
```

### 10. Test the money math and keep those tests
Unit tests cover conversion, rounding edges, tax applicability, mixed payments and change, cash reconciliation differences and receivable or payable balances after partial payments. Fixtures use fictitious amounts and fictitious tenants. These tests are worth keeping in any test audit (`test-audit`).

✅ Do
```ts
it('keeps USD and EUR separate in a mixed payment', () => {
  const r = settle(cart({ totalUsdMinor: 1000 }), [usd(500), eur(460)], snap('0.92'));
  expect(r.byCurrency).toEqual({ USD: 500, EUR: 460 });
});
```
❌ Don't
```ts
expect(settle(c, p, r).total).toBeCloseTo(10); // float tolerance hides a rounding bug
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `number` dollars with decimals | Float drift across many lines | `amountMinor` integer or Decimal128 |
| Rate looked up at read time | History rewrites itself when the rate moves | Snapshot per transaction |
| `* 0.03` or `* 1.16` in code | Tax rates change by law | Configured rate with effective date |
| Two currencies in one balance | Cash reconciliation cannot match | Per-currency lines |
| `toFixed` in templates or services | Inconsistent rounding and locale | `money` pipe and one money module |
| API returns formatted strings | Clients cannot compute or sort | Number plus currency |
| Multi-document money move without a transaction | Partial writes lose money | Mongo transaction |
| Real customer amounts in fixtures | Exposes customer money data | Fictitious amounts and tenants |

## Review checklist

- [ ] No float arithmetic on money; integers or Decimal128 end to end.
- [ ] Every amount carries a currency; every cross-currency record carries a rate snapshot.
- [ ] Conversion and rounding go through the money module only.
- [ ] No hardcoded tax or rate values.
- [ ] Cash reconciliation, account balances and mixed payments are per currency.
- [ ] Multi-document money moves run in a transaction.
- [ ] Display formatting happens in the pipe; API payloads stay numeric.
- [ ] Exchange gain or loss reads stored snapshots.
- [ ] Money-math tests exist for each new rule and pass the test audit.
- [ ] Any business rule was confirmed against a cited source (`decision-protocol`).

## Adapt to your repo

- How amounts are stored today (integer minor units, Decimal128, or floats that need a migration plan), per collection.
- The rounding mode (half-up or half-even) and where it applies (per line, per total, per payment).
- The currency codes in the data, and which currencies are stored versus only used as rate sources.
- Where FX rates come from, and where they are fetched and cached.
- The shape of the rate snapshot on orders, payments and transfers, if any.
- Each tax rate, its trigger rules, and where it is configured.
- The display format per currency and the money pipe name, if one exists.
- How exchange gain or loss is computed today.
- The decimal library in use on each side, if any.
- Whether the MongoDB deployment supports transactions (replica set).
