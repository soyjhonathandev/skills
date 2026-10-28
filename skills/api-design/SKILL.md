---
name: api-design
description: Use when naming a new API route, choosing verbs and status codes, adding pagination or filters, or shaping money, dates and destructive operations in a request or response.
applies_to: [express-api]
---

# Skill: API Design

> Record the existing naming mix, never rename it; new routes are kebab-case English plural nouns under the API base path with standard verbs, pagination, idempotent money moves and explicit money and date shapes.

## When this applies

- Designing a new endpoint or extending an existing one.
- Writing the contract block for a cross-stack feature (`api-contract` owns the block format).
- Reviewing a route for contract or architecture.

## The existing surface

Before adding anything, record what is there. Older APIs often mix naming styles, for example:
- kebab-case: `bank-accounts`, `pending-accounts`, `join-batches`
- camelCase: `auth/changePassword`, `inventory/updateItemById`, `inventory/addBatch`
- another language than English, for business terms
Actions often appear as path segments (`bank-accounts/transfer`, `orders/return`). Note any versioned route (`extraction/v1`).

## Rules

### 1. Never rename an existing route

The frontend apps and any cached clients call the current paths. Renaming breaks them. A rename is a breaking change handled through `api-contract` (alias, deprecation, removal in a later release).

✅ Do
```ts
inventoryRouter.put('/updateItemById/:id', ...);  // existing, left as is
inventoryRouter.put('/items/:id', ...);            // new alias only if a contract asks for it, same handler
```

❌ Don't
```ts
inventoryRouter.put('/items/:id', ...); // and delete /updateItemById in the same PR
```

### 2. Name new routes as kebab-case English plural nouns

Resources are nouns; the HTTP verb is the action. Non-English business terms stay in DTO field docs and UI, not in new paths. Keep an existing resource's prefix when adding to it (`pending-accounts/...`).

✅ Do
```ts
api.use('/stock-counts', stockCountsRouter);
stockCountsRouter.get('/', list);            // GET /api/stock-counts
stockCountsRouter.post('/', create);         // POST /api/stock-counts
stockCountsRouter.get('/:id', getById);      // GET /api/stock-counts/:id
```

❌ Don't
```ts
router.post('/createCount', ...);            // verb in path, camelCase
router.get('/getAllStockCounts', ...);
```

### 3. Model domain actions as sub-resources or action segments, consistently

When an operation is not plain CRUD (close an invoice, register a partial payment, split a batch), use `POST /<resource>/:id/<action>` in kebab-case. The response returns the updated resource.

✅ Do
```ts
router.post('/invoices/:id/close', ...);
router.post('/pending-accounts/:id/payments', ...);          // partial payment on a receivable or payable
router.post('/inventory/batches/:batchId/split', ...);
```

❌ Don't
```ts
router.get('/invoices/close?id=...', ...);   // state change on GET
router.post('/closeInvoice', ...);
```

### 4. Use verbs and status codes by meaning

| Verb | Use | Success |
|---|---|---|
| GET | read, no side effects | 200 |
| POST | create or domain action | 201 (created) or 200 (action result) |
| PUT | full replace | 200 |
| PATCH | partial update | 200 |
| DELETE | remove | 204 |

Errors: 400 invalid input, 401 not authenticated, 403 no permission for this role, 404 not found in this tenant, 409 business conflict (`INSUFFICIENT_STOCK`, `INVOICE_CLOSED`), 422 only if the repo already uses it, 429 rate limited.

✅ Do
```ts
res.status(201).location(`/api/stock-counts/${sc.id}`).json(toStockCountDto(sc));
throw new AppError(409, 'INVOICE_CLOSED', 'Reopen the invoice before editing');
```

❌ Don't
```ts
router.post('/stock-counts/delete', ...);     // delete through POST on a new route
res.status(200).json({ error: 'not found' }); // error with a success status
```

A record from another tenant answers 404, never 403: a 403 confirms the id exists.

### 5. Paginate every list that can grow

For new endpoints; record the shape existing paginated endpoints use first. Default and maximum page size are part of the contract.

✅ Do
```ts
// GET /api/stock-counts?page=1&pageSize=50&locationId=...&sort=-createdAt
res.json({ items: rows.map(toStockCountDto), page, pageSize, total });
```

❌ Don't
```ts
res.json(await StockCount.find({ tenantId })); // a tenant with 500+ SKUs and years of counts returns everything
```

### 6. Whitelist filter and sort fields

Never pass query strings into a Mongo filter. Map allowed params to typed conditions.

✅ Do
```ts
const SORTABLE = { createdAt: 'createdAt', total: 'totalMinor' } as const;
const filter: FilterQuery<Order> = { tenantId };
if (q.channelId) filter.channelId = toObjectId(q.channelId);
if (q.from) filter.createdAt = { $gte: parseIsoDate(q.from) };
```

❌ Don't
```ts
Order.find({ tenantId, ...req.query }).sort(req.query.sort); // operator injection and arbitrary sort
```

### 7. Make money moves idempotent

Orders, partial payments, transfers between accounts, withdrawals and plan payments must not double-apply when a phone on a weak connection retries. Accept an `Idempotency-Key` header and store the outcome per tenant and key.

✅ Do
```ts
router.post('/bank-accounts/:id/transfers', requireIdempotencyKey, validateBody(transferSchema), asyncHandler(controller.transfer));
// service: if a record exists for (tenantId, key), return its stored response instead of moving money again
```

❌ Don't
```ts
// client retries after a timeout: the transfer runs twice and the cash account goes negative
router.post('/bank-accounts/transfer', asyncHandler(controller.transfer));
```

### 8. Shape money explicitly in every DTO

Never a bare number. Each amount carries its currency, and any converted amount carries the exchange rate snapshot used. Details in `money-and-currency`; confirm the repo's real representation.

✅ Do
```json
{ "amountMinor": 125000, "currency": "EUR", "rate": { "value": "0.9200", "source": "FX_PROVIDER_USD_EUR", "date": "2026-10-21" } }
```

❌ Don't
```json
{ "amount": 1250.5, "rate": 0.92 }
```

### 9. Send dates as ISO 8601 with offset; name business days explicitly

Store instants in UTC. A business day (end-of-day close, daily reports) is a calendar date in the tenant's timezone, sent as `YYYY-MM-DD`.

✅ Do
```json
{ "closedAt": "2026-10-21T22:15:03.120Z", "businessDate": "2026-10-21" }
```

❌ Don't
```json
{ "date": "21/10/2026 6:15 pm" }
```

### 10. Version only on breaking change, by path segment

If a versioned route exists (`extraction/v1`), follow its precedent. New versions are added beside the old one; the old one is removed only through the contract deprecation process.

✅ Do
```ts
api.use('/extraction/v2', extractionV2Router); // v1 keeps serving
```

❌ Don't
```ts
// change the v1 response shape in place because "only the app uses it"
```

### 11. Guard destructive operations

Destructive admin routes (reset a tenant's data, wipe inventory, reverse or return an order, remove a location) wipe or undo tenant data. New destructive routes require an explicit confirmation field, the strongest role, an audit entry, and are never called by tests against anything but a local or disposable test tenant.

✅ Do
```ts
router.post('/admin/reset-inventory', requireRole('tenant:owner'), validateBody(schema({ confirm: literal('RESET_INVENTORY') })), asyncHandler(controller.resetInventory));
```

❌ Don't
```ts
router.get('/admin/reset-tenant', ...); // a link preview or prefetch can wipe a business
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Renaming camelCase or non-English routes "for consistency" | Breaks deployed clients | Leave them; alias through a contract |
| Verb in a new path (`/getOrders`) | Duplicates the HTTP verb, grows the naming mix | Noun path plus verb |
| State change on GET | Prefetch, crawlers and retries trigger it | POST/PATCH/DELETE |
| Unbounded list | Slow for large tenants, memory spikes | Page, pageSize, total |
| `...req.query` into a filter | NoSQL operator injection | Whitelisted typed filters |
| Money as a bare float | Rounding drift, unknown currency | Minor units or decimal string plus currency plus rate |
| Local date strings | Wrong business day near midnight | ISO 8601 UTC plus `businessDate` |
| Retry-unsafe money POST | Double order, double transfer | `Idempotency-Key` |

## Review checklist

- [ ] No existing route renamed or removed without a contract deprecation.
- [ ] New paths are kebab-case English plural nouns under the API base path.
- [ ] Verbs and status codes match meaning; cross-tenant ids answer 404.
- [ ] Lists paginate with a max page size.
- [ ] Filters and sort are whitelisted.
- [ ] Money moves accept an idempotency key.
- [ ] Every amount has a currency; converted amounts carry the rate snapshot.
- [ ] Dates are ISO 8601; business days are explicit.
- [ ] Destructive routes need confirmation, the strongest role and an audit entry.

## Adapt to your repo

- The full route list from the router files, and the naming styles it mixes.
- The pagination shape existing list endpoints use.
- Whether any idempotency support exists.
- How the API decides the business day and which timezone it uses.
- The status codes the API uses today for business conflicts.
- The role names allowed to call destructive operations.
- The money representation in DTOs.
