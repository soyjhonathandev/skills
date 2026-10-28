---
name: logging-observability
description: Use when adding logs, error reporting, request ids, audit entries, health checks or socket.io event logging to an Express API.
applies_to: [express-api]
---

# Skill: Logging and Observability

> Structured JSON logs with a request id, tenant id and user id on every line, PII and money redacted, a separate audit log for money and destructive operations, and errors reported once.

## When this applies

- Any new log line, error path or background job in the API.
- Money moves, inventory changes, end-of-day closes, support sessions and destructive admin routes.
- socket.io events and health or metrics endpoints.
- Security review (PII) and performance review (log volume).

Use the repo's logging library (pino or winston are the usual choices). Examples use a pino-style API.

## Rules

### 1. Log structured objects through the shared logger, never `console.log`

One logger, JSON output, a message plus a context object. `console.log` loses level, request id and redaction.

✅ Do
```ts
req.log.info({ invoiceId, businessDate }, 'invoice closed');
```

❌ Don't
```ts
console.log('invoice closed', invoice); // whole document, no level, no request id
```

### 2. Give every request an id and return it

A request id middleware runs first. It accepts an incoming id from a trusted proxy or generates one, sets the response header, and the error body carries it (`error.requestId`) so a user's screenshot leads to the log line.

✅ Do
```ts
app.use((req, res, next) => {
  req.id = (req.header('x-request-id') as string) || randomUUID();
  res.setHeader('x-request-id', req.id);
  req.log = logger.child({ requestId: req.id });
  next();
});
```

❌ Don't
```ts
// no id: support cannot match "error closing invoice" on a user's screen to any log line
```

The header name above is an example; use the one your proxy sets.

### 3. Bind tenant and user ids to a child logger, never names

After auth and tenant middleware, add `tenantId` and `userId`. Ids only: never the tenant owner's name, the user's email or the business name.

✅ Do
```ts
req.log = req.log.child({ tenantId: req.tenant.id, userId: req.user.id });
```

❌ Don't
```ts
req.log = req.log.child({ tenant: req.tenant.subdomain, user: req.user.email, business: req.tenant.name });
```

### 4. Redact PII, secrets and money at the logger

Configure redaction once so a careless `{ body }` cannot leak. The list covers national and tax ids (`nationalId`, `taxId`), phone, email, address, password, tokens, authorization and cookie headers, card data, bank account numbers and amounts.

✅ Do
```ts
const logger = pino({
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.token', '*.nationalId', '*.taxId',
            '*.phone', '*.email', '*.address', '*.cardNumber', '*.accountNumber', '*.amountMinor', '*.balanceMinor'],
    censor: '[REDACTED]',
  },
});
```

❌ Don't
```ts
req.log.info({ body: req.body }, 'payment registered'); // customer id number, phone and amount in plain text
```

Amounts are redacted from app logs by default. Whether amounts may appear in any log, and which, is a team policy decision. The audit log (rule 7) is where money facts live.

### 5. Use levels by meaning

`fatal` the process must stop; `error` a 5xx or a failed job; `warn` an expected but notable condition (rate limit hit, exchange rate fetch failed and the previous one is used); `info` one line per business event; `debug` off in production.

✅ Do
```ts
req.log.warn({ source: 'FX_PROVIDER' }, 'rate fetch failed, using last snapshot');
req.log.error({ err }, 'order submit failed');
```

❌ Don't
```ts
logger.error('INSUFFICIENT_STOCK');   // a 409 is a normal business answer, not an error
logger.info(JSON.stringify(rows));     // a report dump at info
```

### 6. Log errors once, at the central handler

Services throw; the error handler logs 5xx with the error object and request context and reports to error tracking. Catch-log-rethrow at each layer produces three copies of one failure.

✅ Do
```ts
if (e.status >= 500) { req.log.error({ err }, 'request failed'); errorTracker.capture(err, { requestId: req.id, tenantId: req.tenant?.id }); }
```

❌ Don't
```ts
try { await svc.transfer(...) } catch (err) { logger.error(err); throw err; } // repeated in controller and service
```

Use whatever error tracking tool the project has (Sentry or similar). Never send request bodies to it.

### 7. Keep an audit log for money and destructive operations

Who, what, when, on which tenant and record, for: order submit and return, partial payments on receivables and payables, transfers and withdrawals, end-of-day close with overage or shortage, price and rate changes, destructive admin routes, support sessions, permission changes. The audit log is durable data in its own store, not app logs that rotate.

✅ Do
```ts
await auditLog.record({
  tenantId: req.tenant.id, actorId: req.user.id, action: 'bank-account.withdraw',
  targetId: accountId, at: new Date(), requestId: req.id,
}, { session });
```

❌ Don't
```ts
req.log.info('user withdrew money'); // rotates away in days, no actor, no target
```

Audit entries written inside the same transaction as the money move cannot drift from it.

### 8. Log socket.io events at connection and failure, not per message

Log connect and disconnect with tenant and user ids, auth failures and handler errors. Per-message logs for realtime fan-out (inventory updates, open orders) flood the logs.

✅ Do
```ts
io.on('connection', (socket) => {
  const log = logger.child({ socketId: socket.id, tenantId: socket.data.tenantId, userId: socket.data.userId });
  log.info('socket connected');
  socket.on('disconnect', (reason) => log.info({ reason }, 'socket disconnected'));
});
```

❌ Don't
```ts
socket.onAny((event, payload) => logger.info({ event, payload })); // every stock update with its payload
```

### 9. Time slow paths and expose health

Log duration for exports, AI or document extraction and report aggregations. A health endpoint answers liveness, and readiness checks the database.

✅ Do
```ts
const t0 = performance.now();
const result = await extractionService.extract(req.tenant.id, fileKey);
req.log.info({ ms: Math.round(performance.now() - t0), lines: result.lines.length }, 'invoice extracted');
```

❌ Don't
```ts
// a 40 s extraction with no timing: nobody knows it is slow until tenants complain
```

### 10. Keep tests and fixtures free of real data in logs

Test logs use a fictitious tenant such as `demo-store`; never paste production log lines with ids, amounts or names into issues, PRs or prompts.

✅ Do
```ts
logger.child({ tenantId: 'demo-store-id' }).info('fixture loaded');
```

❌ Don't
```ts
// PR description quotes a production log line with a real tenant id and amount
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `console.log` in API code | No level, no id, no redaction | Shared structured logger |
| Logging `req.body` or full documents | Leaks id numbers, phones, amounts | Log ids and selected fields |
| Names or emails as log context | PII in every line | `tenantId` and `userId` |
| Catch, log, rethrow at each layer | Duplicate errors, noisy alerts | Log once at the error handler |
| 4xx logged as `error` | Alert fatigue | `info` or `warn` |
| Money history in app logs | Rotates away, no structure | Audit log in its own store |
| Per-message socket logs | Log volume explodes | Connect, disconnect, failures |

## Review checklist

- [ ] No `console.log`; all logs go through the shared logger.
- [ ] Every log line carries `requestId`; tenant routes add `tenantId` and `userId`.
- [ ] No names, emails, national or tax ids, phones, tokens or amounts in log context.
- [ ] Redaction config covers any new sensitive field name.
- [ ] Errors logged once; 5xx reported to error tracking without bodies.
- [ ] Money and destructive operations write an audit entry in the same transaction.
- [ ] Slow paths log duration.
- [ ] Error responses include the request id.

## Adapt to your repo

- The logging library and its config file.
- Whether a request id middleware exists, and the header name.
- The error tracking tool and how it is initialized.
- Whether an audit log or activity collection exists.
- The team policy for amounts in logs.
- Health and metrics endpoints, and where logs are shipped.
- The sensitive field names used in models, for the redaction list.
