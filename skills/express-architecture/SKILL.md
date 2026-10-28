---
name: express-architecture
description: Use when adding or moving an Express route, controller, service, model or middleware, or deciding which layer owns a piece of logic.
applies_to: [express-api]
---

# Skill: Express Architecture

> Router -> controller -> service -> model, one router per resource under `/api`, and a fixed middleware order.

## When this applies

- Adding a resource or endpoint to the API.
- Deciding where logic lives: HTTP parsing, business rules, persistence.
- Touching the app entry, the router index or global middleware (shared files: one owner per change set).
- Reviewing a diff for architecture.

The folder layout below is an example; use the repo's real one:
`src/routes`, `src/controllers`, `src/services`, `src/models`, `src/middleware`.

## Rules

### 1. Keep the four layers and their direction

Routes wire URLs to middleware and handlers. Controllers translate HTTP to a service call and back. Services hold business rules and transactions. Models define schema, indexes and the tenant plugin. Calls only go down.

✅ Do
```ts
// routes/invoices.routes.ts
router.post('/:id/void', requireRole('invoice:void'), validateBody(voidInvoiceSchema), invoiceController.void);

// controllers/invoice.controller.ts
export async function voidInvoice(req: Request, res: Response) {
  const result = await invoiceService.void(req.tenant.id, req.params.id, req.body, req.user.id);
  res.status(200).json(result);
}

// services/invoice.service.ts
export async function voidInvoice(tenantId: string, invoiceId: string, input: VoidInput, userId: string) {
  // checks the invoice is voidable, reverses its payments, writes the audit entry
}
```

❌ Don't
```ts
router.post('/:id/void', async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);     // no tenant scope, model in a route
  Object.assign(invoice, req.body);                          // no validation, mass assignment
  invoice.balance = invoice.total - req.body.refunded;       // business rule in the route
  await invoice.save();
  res.json(invoice);
});
```

### 2. Mount one router per resource under `/api`

Each resource gets one router file and one mount line. The router index is the only place that knows the prefix.

✅ Do
```ts
// routes/index.ts
const api = Router();
api.use('/orders', ordersRouter);
api.use('/invoices', invoicesRouter);
api.use('/accounts', accountsRouter);
app.use('/api', api);
```

❌ Don't
```ts
app.post('/api/orders/addLine', ...);              // routes scattered in the entry file
ordersRouter.post('/../accounts/transfer', ...);   // a router reaching into another resource
```

### 3. Apply global middleware in one fixed order

Order decides correctness: the request id must exist before anything logs, auth before tenant, tenant before validation that reads tenant settings, the error handler last.

✅ Do
```ts
app.disable('x-powered-by');
app.use(requestId());                    // 1. id on req and response header
app.use(securityHeaders());              // 2. helmet or equivalent
app.use(cors(corsOptions));              // 3. CORS
app.use(rateLimiter);                    // 4. express-rate-limit
app.use(express.json({ limit: '1mb' })); // 5. body parsing with a limit
app.use('/api', authenticate, resolveTenant, apiRouter); // 6-8. auth, tenant, routes (validation per route)
app.use(notFound);                       // 9. 404 in the standard error shape
app.use(errorHandler);                   // 10. central error handler, always last
```

❌ Don't
```ts
app.use(errorHandler);           // registered before routes: never reached
app.use('/api', apiRouter);
app.use(express.json());         // body parsed after the routes ran
app.use(resolveTenant);          // tenant resolved after queries already ran
```

The body limit value above is an example. Use the repo's real one.

### 4. Put transactions and cross-resource rules in services

Placing an order reserves stock, records the payment and may open a receivable. That is one service call with one transaction, not three controller calls.

✅ Do
```ts
export async function placeOrder(tenantId: string, input: PlaceOrderInput, userId: string) {
  return withTransaction(async (session) => {
    const order = await orderRepo.create(tenantId, input, session);
    await inventoryService.reserveForOrder(tenantId, order.lines, session);
    await paymentService.record(tenantId, order.payments, session);
    if (input.onCredit) await receivableService.open(tenantId, order, session);
    return order;
  });
}
```

❌ Don't
```ts
// controller orchestrating persistence, no transaction: a crash mid-way leaves stock reserved and no order
await Order.create(req.body);
await Inventory.updateMany(...);
await Account.updateOne(...);
```

### 5. Services never touch `req` or `res`

Services take plain arguments (tenant id, DTO, user id) so they run from routes, socket.io handlers, jobs and tests alike.

✅ Do
```ts
await inventoryService.transfer(req.tenant.id, { itemId, fromLocationId, toLocationId, qty }, req.user.id);
```

❌ Don't
```ts
await inventoryService.transfer(req, res); // service now depends on Express and cannot run from a socket handler
```

### 6. Controllers stay thin and return DTOs

The controller maps the service result to the response DTO pinned in the contract (see `api-contract`). It never returns a raw Mongoose document.

✅ Do
```ts
const line = await orderService.splitLine(req.tenant.id, req.params.lineId, req.body);
res.status(201).json(toOrderLineDto(line));
```

❌ Don't
```ts
res.json(await OrderLine.findById(id)); // leaks __v, internal fields, tenantId, populated secrets
```

### 7. Name one owner for shared files in parallel work

The app entry, the router index, global middleware and shared DTOs are shared files. When several people or agents work in parallel, exactly one track edits them; other tracks request the mount line through that track.

✅ Do
```ts
// plan, api track: files_to_modify includes routes/index.ts
// the e2e or docs track asks the api track to add: api.use('/refunds', refundsRouter)
```

❌ Don't
```ts
// two parallel worktrees both append a mount line to routes/index.ts: merge conflict and lost route
```

### 8. Add a new resource with the same recipe every time

Recipe for a new resource (example: `stock-counts` for physical inventory counts per location):
1. Contract pinned (method, path, auth, tenant scope, DTOs, errors, pagination) in `api-contract` format.
2. Model with the tenant plugin and indexes leading with `tenantId` (`mongodb-mongoose`).
3. Service with the business rules; transaction if it moves stock or money.
4. Controller and validation schema.
5. Router file plus one mount line in the router index (owner track only).
6. Integration test with supertest against a fresh test database and a tenant isolation test (`multi-tenancy`).

✅ Do
```ts
api.use('/stock-counts', stockCountsRouter); // kebab-case English plural, see api-design
```

❌ Don't
```ts
api.use('/stockCountList', router); // new route adding to the naming mix
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Mongoose calls inside a route callback | No tenant scope, no reuse, untestable | Service plus repository/model with the tenant plugin |
| Service takes `req`/`res` | Cannot run from socket.io, jobs or tests | Pass tenant id, DTO, user id |
| Controller chains several writes | Partial state on failure (stock gone, no order) | One service method, one transaction |
| Error handler registered before routes | Errors fall through to Express default HTML | Register it last |
| Router mounted in two places | Duplicate routes, unclear prefix | One mount line in the router index |
| Parallel tracks editing the router index | Merge conflicts and lost mounts | One owner track named in the plan |

## Review checklist

- [ ] New logic sits in a service; the route file only wires middleware and the handler.
- [ ] Services have no Express types in their signatures.
- [ ] Money or stock moves happen inside one transaction in one service call.
- [ ] Response is a DTO, never a raw document.
- [ ] New router mounted once, under `/api`, with a kebab-case English path.
- [ ] Middleware order unchanged or the change is justified in the PR.
- [ ] Shared files touched only by the track that owns them.
- [ ] Tenant middleware runs before any handler that queries.

## Adapt to your repo

- The real folders for routes, controllers, services and models.
- The router index file name and the API base path.
- The global middleware order in the app entry.
- The JSON body limit.
- TypeScript or JavaScript.
- Whether a transaction helper exists, and its name.
- Where socket.io handlers live and whether they call services.
- The Express major version.
