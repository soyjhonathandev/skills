---
name: express-good-practices
description: "Use when writing or reviewing any Express handler, middleware or service: async errors, the error handler, config, blocking work and shutdown."
applies_to: [express-api]
---

# Skill: Express Good Practices

> Every async error reaches one central handler, which answers in one error shape; config is read once; nothing heavy blocks the event loop.

## When this applies

- Any new or changed handler, middleware or service in the API.
- Report and export endpoints (xlsx, PDF) and other slow work such as AI extraction.
- Startup, shutdown and configuration code.

## Rules

### 1. Propagate async errors to the error handler

Express 4 does not catch rejected promises: an `await` that throws hangs the request or crashes the process. Express 5 forwards them. Wrap handlers (or use `express-async-errors`) unless the repo is confirmed on Express 5.

✅ Do
```ts
export const asyncHandler =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: Request, res: Response, next: NextFunction) =>
    fn(req, res, next).catch(next);

router.post('/:id/pay', validateBody(payInvoiceSchema), asyncHandler(invoicesController.pay));
```

❌ Don't
```ts
router.post('/:id/pay', async (req, res) => {
  const result = await invoicesService.pay(...); // a rejection here is unhandled in Express 4
  res.json(result);
});
```

### 2. Throw typed errors, answer in one shape

Services throw an `AppError` with a stable code. Only the error handler builds the response. Use this shape for new endpoints; keep an existing shape if the repo already has one.

✅ Do
```ts
export class AppError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown[]) {
    super(message);
  }
}

if (item.qty < qty) throw new AppError(409, 'INSUFFICIENT_STOCK', 'Not enough stock for this item', [{ itemId, available: item.qty }]);

// error handler, registered last
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  const e = err instanceof AppError ? err : new AppError(500, 'INTERNAL', 'Unexpected error');
  if (e.status >= 500) req.log.error({ err }, 'request failed');
  res.status(e.status).json({ error: { code: e.code, message: e.message, details: e.details ?? [], requestId: req.id } });
}
```

❌ Don't
```ts
res.status(400).send('out of stock');                 // string body, free text, no code
res.status(500).json({ err: e.stack });               // leaks internals
return res.json({ success: false, msg: 'error' });    // 200 with a failure inside
```

### 3. Keep business logic out of middleware

Middleware answers cross-cutting questions (who, which tenant, is the body valid, too many requests). Rules like "an order must be open to add lines" belong to the service, where they are tested and reused by socket handlers.

✅ Do
```ts
// services/order.service.ts
const order = await orderRepo.findOpen(tenantId, orderId, session);
if (!order) throw new AppError(409, 'ORDER_CLOSED', 'The order is no longer open');
```

❌ Don't
```ts
app.use('/api/orders', async (req, res, next) => {
  const order = await Order.findOne({ user: req.user.id, open: true }); // hidden rule, extra query on every orders route
  if (!order) return res.status(400).end();
  next();
});
```

### 4. Read configuration once, at startup, and fail fast

Parse and validate env vars in one config module. Code imports the config object, never `process.env`. Use the repo's real env var names; never invent them, and never print their values.

✅ Do
```ts
// config.ts
const required = ['<database URI var>', '<payment webhook secret var>'] as const; // the repo's real names
for (const name of required) if (!process.env[name]) throw new Error(`Missing env var ${name}`);
export const config = Object.freeze({ mongoUri: process.env['<database URI var>']!, port: Number(process.env['<port var>']) });
```

❌ Don't
```ts
const rate = process.env.FX_RATE || 36.5;      // config read deep in code, with a business value as default
console.log('config', process.env);            // prints secrets
```

### 5. Never block the event loop on the request path

xlsx and PDF generation for reports and AI extraction can take seconds. Stream the output, move it to a job, or both. One slow export must not freeze the users of every tenant.

✅ Do
```ts
router.get('/report', asyncHandler(async (req, res) => {
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  const cursor = Order.find({ tenantId: req.tenant.id }).lean().cursor();
  await streamXlsx(cursor, res);            // rows written as they come
}));
```

❌ Don't
```ts
const all = await Order.find({ tenantId }).lean();              // whole collection in memory
const buf = XLSX.write(buildWorkbook(all), { type: 'buffer' }); // CPU-bound, blocks every request
fs.writeFileSync('/tmp/report.xlsx', buf);                      // sync fs on the hot path
```

### 6. Respond once, then stop

After `res.json`, `res.end` or `next(err)`, return. Double responses throw "headers already sent" and hide the original error.

✅ Do
```ts
if (!order) return next(new AppError(404, 'ORDER_NOT_FOUND', 'Order not found'));
return res.json(toOrderDto(order));
```

❌ Don't
```ts
if (!order) next(new AppError(404, 'ORDER_NOT_FOUND', 'Order not found'));
res.json(toOrderDto(order)); // runs anyway
```

### 7. Validate input at the edge with one schema per route

Use the repo's validation library (zod, Joi, celebrate, express-validator) through one `validateBody(schema)` / `validateQuery(schema)` middleware. Mongoose validation is the last line, not the first.

✅ Do
```ts
const addLineSchema = schema({ itemId: objectId(), locationId: objectId(), qty: positiveInt(), unitPriceMinor: nonNegativeInt(), currency: oneOf(['USD', 'EUR']), deliverBy: optionalIsoDate() });
router.post('/:id/lines', validateBody(addLineSchema), asyncHandler(ordersController.addLine));
```

❌ Don't
```ts
const qty = parseFloat(req.body.qty) || 0; // silent coercion, negative or NaN quantities pass
```

### 8. Shut down gracefully

On SIGTERM stop accepting connections, let in-flight requests (a checkout in a transaction) finish, close socket.io, then close the database.

✅ Do
```ts
process.on('SIGTERM', async () => {
  server.close(async () => {
    await io.close();
    await mongoose.connection.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
});
```

❌ Don't
```ts
process.on('SIGTERM', () => process.exit(0)); // kills open transactions and socket clients mid-checkout
```

### 9. Fail loudly on unhandled rejections

Log with context and exit so the process manager restarts a clean process. Never swallow.

✅ Do
```ts
process.on('unhandledRejection', (err) => { logger.fatal({ err }, 'unhandled rejection'); process.exit(1); });
```

❌ Don't
```ts
process.on('unhandledRejection', () => {}); // the API keeps running in an unknown state
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Bare `async` handler in Express 4 | Rejection never reaches the error handler | `asyncHandler` or `express-async-errors` |
| `try/catch` in every controller that builds its own error JSON | Several error shapes for one client | Throw `AppError`, one handler formats |
| `200` with `{ success: false }` | Clients and monitoring read failures as success | Proper 4xx/5xx status |
| `process.env` read in services | Untestable, unvalidated, scattered | One frozen config module |
| Sync xlsx/PDF build of a whole tenant | Blocks all tenants on one process | Stream, cursor, or background job |
| Business rule in global middleware | Hidden, untested, extra queries | Service method |
| `catch (e) {}` | Lost money or stock errors | Rethrow or convert to `AppError` |

## Review checklist

- [ ] Every async handler is wrapped (or Express 5 confirmed).
- [ ] Errors are `AppError` with an UPPER_SNAKE code; no ad hoc error JSON.
- [ ] 5xx are logged with the request id; 4xx are not logged as errors.
- [ ] No `process.env` outside the config module; no secret printed.
- [ ] Exports and AI extraction do not block the event loop.
- [ ] Every `res.*` or `next(err)` is followed by `return` where code continues.
- [ ] Input validated by a schema at the route; no manual `parseFloat`.
- [ ] No empty catch blocks.

## Adapt to your repo

- The Express major version.
- Whether `express-async-errors` or a wrapper already exists.
- The existing error response shape, if any.
- The validation library and its middleware.
- The config module path and the env var names (names only).
- The xlsx and PDF libraries, and whether reports already stream or run as jobs.
- The process manager and current shutdown handling.
