---
name: mongodb-mongoose
description: Use when creating or changing a Mongoose schema, index, query, aggregation, transaction or migration in an Express API.
applies_to: [express-api]
---

# Skill: MongoDB and Mongoose

> Explicit schemas with a required `tenantId`, indexes that lead with it, lean projected reads, one transaction per money or stock move, no floats, and idempotent migrations.

## When this applies

- New collection or field (inventory items, orders, payments, FX results).
- New query, aggregation or report (revenue summaries, FX results, statistics).
- Any write that moves money or stock.
- Backfills and data migrations.

## Rules

### 1. Declare every field with a type, and require `tenantId`

Every tenant-owned collection has `tenantId` required and set by the tenant plugin, never by the client. See `multi-tenancy`.

✅ Do
```ts
const stockItemSchema = new Schema({
  tenantId:   { type: Schema.Types.ObjectId, required: true, immutable: true },
  productId:  { type: Schema.Types.ObjectId, ref: 'Product', required: true },
  locationId: { type: Schema.Types.ObjectId, ref: 'Location', required: true },
  qty:        { type: Number, required: true, min: 0, validate: Number.isInteger },
  unitCost:   { amountMinor: { type: Number, required: true, validate: Number.isInteger }, currency: { type: String, enum: ['USD', 'EUR'], required: true } },
  expiresAt:  { type: Date },
}, { timestamps: true, strict: 'throw' });
stockItemSchema.plugin(tenantScope);
```

❌ Don't
```ts
const stockSchema = new Schema({ data: Schema.Types.Mixed }, { strict: false }); // anything goes, no tenant
```

### 2. Lead compound indexes with `tenantId`

Every query is tenant-scoped, so every index starts with `tenantId`, then equality fields, then sort, then range. Unique constraints are per tenant.

✅ Do
```ts
stockItemSchema.index({ tenantId: 1, productId: 1, locationId: 1 });
productSchema.index({ tenantId: 1, sku: 1 }, { unique: true });
orderSchema.index({ tenantId: 1, createdAt: -1 });
```

❌ Don't
```ts
productSchema.index({ sku: 1 }, { unique: true }); // blocks two tenants from using the same SKU
orderSchema.index({ createdAt: -1 });              // scans every tenant's orders
```

### 3. Read with `lean()` and a projection

Reads that do not save return plain objects and only the fields the DTO needs.

✅ Do
```ts
const products = await Product.find({ categoryId }, { name: 1, sku: 1, minStock: 1 }).lean();
```

❌ Don't
```ts
const products = await Product.find({}); // full hydrated documents for a dropdown
```

### 4. Use one transaction for every multi-document money or stock move

Placing an order decrements stock, credits the account per payment and opens a receivable for a credit order. All or nothing. Transactions need a replica set, locally too (the dev Docker setup must run one).

✅ Do
```ts
await mongoose.connection.transaction(async (session) => {
  for (const line of order.lines) {
    const res = await StockItem.updateOne({ _id: line.stockItemId, qty: { $gte: line.qty } }, { $inc: { qty: -line.qty } }, { session });
    if (res.modifiedCount !== 1) throw new AppError(409, 'INSUFFICIENT_STOCK', 'Stock ran out', [{ stockItemId: line.stockItemId }]);
  }
  await Account.updateOne({ _id: pay.accountId }, { $inc: { balanceMinor: pay.amountMinor } }, { session });
  if (order.onCredit) await Receivable.create([{ orderId: order._id, balanceMinor: order.totalMinor, currency: order.currency }], { session });
});
```

❌ Don't
```ts
const item = await StockItem.findById(id);
item.qty -= line.qty;               // read-modify-write race between two users
await item.save();                  // no session: the account credit can fail after this succeeded
```

### 5. Never store money as a JS float

Use integer minor units (`amountMinor`) or `Decimal128` with an explicit rounding rule; see `money-and-currency`. Each transaction that converts currency stores its FX rate snapshot.

✅ Do
```ts
const paymentSchema = new Schema({
  amountMinor: { type: Number, required: true, validate: Number.isInteger },
  currency:    { type: String, enum: ['USD', 'EUR'], required: true },
  rate: { value: { type: Schema.Types.Decimal128, required: true }, source: { type: String, enum: ['CENTRAL_BANK', 'MARKET', 'custom'], required: true }, date: { type: Date, required: true } },
});
```

❌ Don't
```ts
const paymentSchema = new Schema({ amount: Number, rate: Number }); // 0.1 + 0.2 in a daily close
```

### 6. Use atomic operators instead of read-modify-write

`$inc`, `$push`, conditional filters and `findOneAndUpdate` with `{ new: true }` avoid lost updates when two sessions touch the same balance or stock row.

✅ Do
```ts
await Receivable.findOneAndUpdate(
  { _id: receivableId, balanceMinor: { $gte: payment.amountMinor } },
  { $inc: { balanceMinor: -payment.amountMinor }, $push: { payments: payment } },
  { new: true, session },
);
```

❌ Don't
```ts
const r = await Receivable.findById(receivableId);
r.balanceMinor = r.balanceMinor - payment.amountMinor; // overpayment if two payments land together
await r.save();
```

### 7. Avoid N+1 queries and deep populate

Batch-load related documents with `$in`, or use one aggregation. `populate` is fine for one level on a bounded list; never inside a loop.

✅ Do
```ts
const stock = await StockItem.find({ productId: { $in: products.map((p) => p._id) } }).lean();
const byProduct = groupBy(stock, (s) => String(s.productId));
```

❌ Don't
```ts
for (const p of products) p.stock = await StockItem.find({ productId: p._id }); // 500 SKUs, 500 queries
```

### 8. Build reports with aggregations that match on `tenantId` first

Revenue summaries, FX results (exchange-difference gains and losses) and statistics run as pipelines whose first stage is `$match` on `tenantId` plus the date range, so the index is used. Sum amounts per currency; never sum two currencies together.

✅ Do
```ts
Order.aggregate([
  { $match: { tenantId, createdAt: { $gte: from, $lt: to } } },
  { $unwind: '$payments' },
  { $group: { _id: '$payments.currency', totalMinor: { $sum: '$payments.amountMinor' } } },
]);
```

❌ Don't
```ts
const orders = await Order.find({ tenantId }).lean();          // load all, sum in JS
const total = orders.reduce((s, x) => s + x.total, 0);         // mixes currencies
```

Aggregations bypass Mongoose middleware, so a tenant plugin does not scope them. The `$match` on `tenantId` is mandatory and the multi-tenancy mechanism must cover it.

### 9. Run `explain()` on every new query shape

Before merging a new query or aggregation, check it uses an index (`IXSCAN`, not `COLLSCAN`) on realistic seeded data. Paste the winning plan summary in the PR.

✅ Do
```ts
const plan = await Order.find({ tenantId, createdAt: { $gte: from } }).sort({ createdAt: -1 }).explain('queryPlanner');
```

❌ Don't
```ts
// ships a new statistics query tested on 10 documents
```

### 10. Write migrations idempotent and reversible

Backfills (adding a rate snapshot to old orders, splitting a field) run in batches, can run twice without damage, and have a documented rollback. Never run one against production from a developer machine.

✅ Do
```ts
await Order.updateMany({ tenantId, rate: { $exists: false } }, [{ $set: { rate: { value: '$legacyRate', source: 'CENTRAL_BANK', date: '$createdAt' } } }]);
```

❌ Don't
```ts
await Order.updateMany({}, { $set: { rate: { value: 36.5 } } }); // all tenants, invented value, not repeatable
```

### 11. Keep version-specific behaviour explicit

Mongoose 6 vs 7+ changed callbacks (removed in 7) and `strictQuery` defaults. Set `strictQuery` explicitly and never use callbacks.

✅ Do
```ts
mongoose.set('strictQuery', true);
const product = await Product.findOne({ sku }).lean();
```

❌ Don't
```ts
Product.findOne({ sku }, (err, product) => { ... }); // removed in Mongoose 7
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Collection without `tenantId` | Data leaks across customers | Required `tenantId` plus tenant plugin |
| Index without `tenantId` prefix | Scans all tenants, global uniques | Compound index led by `tenantId` |
| `Number` float for money | Rounding drift in totals | Minor units or `Decimal128` |
| Read-modify-write on balances or stock | Lost updates between users | `$inc` with a guard filter |
| Multi-write without a session | Stock gone, payment missing | One transaction |
| `populate` in a loop | N+1, slow lists | `$in` batch or aggregation |
| Aggregation without `$match` on `tenantId` | Middleware does not scope it | First stage matches tenant |
| One-shot migration with literals | Not repeatable, wrong for some tenants | Idempotent, batched, reversible |

## Review checklist

- [ ] New tenant-owned schema has required immutable `tenantId` and the tenant plugin.
- [ ] Indexes lead with `tenantId`; unique constraints are per tenant.
- [ ] Reads use `lean()` and a projection.
- [ ] Money and stock moves run in one transaction with guarded atomic updates.
- [ ] No float money; each money transaction stores currency and rate snapshot.
- [ ] No N+1; populate depth one at most.
- [ ] Aggregations start with `$match` on `tenantId`.
- [ ] `explain()` output in the PR for new query shapes.
- [ ] Migration is idempotent, batched, reversible and tested on a disposable test database.

## Adapt to your repo

- The Mongoose and MongoDB versions.
- The tenant scoping mechanism and the tenant field name.
- The money representation and rounding rule.
- How FX rates are stored and linked to transactions.
- Whether production and dev run a replica set, and whether transactions are already used.
- The migration tool and where migrations live.
- The real collection names for the models in these examples.
- How quantities are stored (units, boxes, grams).
