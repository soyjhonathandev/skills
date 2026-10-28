---
name: express-security
description: Use when writing or reviewing any Express endpoint that reads tenant data, accepts input or files, handles auth, payments or webhooks, or runs a destructive operation.
applies_to: [express-api]
---

# Skill: Express Security

> Every query is tenant-scoped, every action checks the user's role, input is typed before it reaches Mongo, and payments, uploads and destructive routes get their own guards.

## When this applies

- Any endpoint; most of all money, inventory, auth, uploads, payment webhooks and destructive operations, and changes to CORS, rate limits, headers or auth.
- Security reviews, especially on money and tenant boundaries.

## Rules

### 1. Scope every query to the tenant through the one mechanism

Tenant isolation is the first security rule of a multi-tenant product. Scoping goes through the shared plugin or repository, never by hand. Full rules in `multi-tenancy`.

✅ Do
```ts
const invoice = await invoiceRepo.findById(req.tenant.id, req.params.id); // repository adds tenantId
if (!invoice) throw new AppError(404, 'INVOICE_NOT_FOUND', 'Not found');
```

❌ Don't
```ts
const invoice = await Invoice.findById(req.params.id); // any tenant's invoice by guessing an id
```

### 2. Authorize per role and module on the server

Users get module permissions by role: a cashier sells but cannot see margins or touch inventory. The frontend route guard hides the screen; the API is the real gate.

✅ Do
```ts
router.get('/margins', requirePermission('reports:view-cost'), asyncHandler(reportsController.margins));
router.post('/withdraw', requirePermission('accounts:withdraw'), asyncHandler(accountsController.withdraw));
```

❌ Don't
```ts
router.get('/margins', asyncHandler(reportsController.margins)); // "the menu item is hidden for cashiers"
```

### 3. Type-check input before it reaches Mongo (NoSQL operator injection)

`{ "password": { "$ne": null } }` in a JSON body or `?sku[$gt]=` in a query string turns a lookup into a match-anything. Validate types with the route schema, and strip keys starting with `$` or containing `.`.

✅ Do
```ts
const signinSchema = schema({ email: email(), password: string().min(1) });
router.post('/signin', authLimiter, validateBody(signinSchema), asyncHandler(authController.signin));
const user = await User.findOne({ email: String(body.email) });
```

❌ Don't
```ts
User.findOne({ email: req.body.email, password: req.body.password }); // object values pass; and never $where with input
```

### 4. Never assign the request body to a model

Pick allowed fields from the validated DTO. Mass assignment lets a client set `tenantId`, `balanceMinor`, `role` or `plan`.

✅ Do
```ts
const { name, phone, email } = req.body as CreateCustomerDto;
await customerRepo.create(req.tenant.id, { name, phone, email });
```

❌ Don't
```ts
await Customer.create(req.body);                          // client sends { tenantId, balanceMinor }
await User.findByIdAndUpdate(id, req.body);               // client sends { role: 'owner' }
```

### 5. Rate limit by endpoint risk

A global limiter is only a flood guard. Auth and recovery endpoints need a much stricter limiter keyed by IP plus account, so codes and passwords cannot be guessed at volume.

✅ Do
```ts
const authLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 10, keyGenerator: (req) => `${req.ip}:${String(req.body?.email)}` });
router.post('/signin', authLimiter, ...);
router.post('/password-reset/request', authLimiter, ...);
router.post('/password-reset/verify', authLimiter, ...);
```

❌ Don't
```ts
// only a global limit on every route: auth endpoints share the same generous budget as reads
```

The numbers above are examples; the team sets the real ones.

### 6. Restrict CORS to your own origins

Allow only the origins that serve your frontends, by list or by an anchored pattern. Before tightening an existing open policy, find out which clients or integrations depend on it.

✅ Do
```ts
const allowed = /^https:\/\/([a-z0-9-]+\.)?example\.com$/;
app.use(cors({ origin: (origin, cb) => cb(null, !origin || allowed.test(origin)), credentials: true }));
```

❌ Don't
```ts
app.use(cors()); // any site can call the API from a logged-in user's browser if auth rides on cookies
```

### 7. Hide the framework fingerprint

Disable `x-powered-by` or add helmet. Keep a strict CSP on API responses (`default-src 'none'`).

✅ Do
```ts
app.disable('x-powered-by');
app.use(helmet());
```

❌ Don't
```ts
// default Express headers advertise the stack to scanners
```

### 8. Handle tokens and sessions strictly

Whatever the auth mechanism (JWT bearer or session cookie), verify signature, expiry and the tenant claim on every request; tokens never go in URLs or logs. Support sessions (staff entering a tenant) are audited with who, which tenant, when and why.

✅ Do
```ts
const claims = verifyToken(token);                        // signature + exp + audience
if (claims.tenantId !== req.tenant.id) throw new AppError(403, 'TENANT_MISMATCH', 'Wrong tenant');
if (claims.supportSessionId) auditLog.record({ kind: 'support-access', actor: claims.sub, tenantId: req.tenant.id });
```

❌ Don't
```ts
const claims = jwt.decode(token);                         // decode is not verify
res.redirect(`https://${tenant}.example.com/?token=${token}`); // token in URL, history and logs
```

### 9. Constrain file uploads

Limit size and type, detect the type from content, prefix the storage key with the tenant, never use the client file name as the key, and prefer presigned URLs with short expiry. Uploaded documents are tenant data.

✅ Do
```ts
const upload = multer({ limits: { fileSize: 10 * 1024 * 1024 }, storage: multer.memoryStorage() });
const type = await detectType(file.buffer);               // magic bytes, not file.mimetype
if (!['application/pdf', 'image/jpeg', 'image/png'].includes(type)) throw new AppError(400, 'UNSUPPORTED_FILE', 'PDF or image only');
const key = `${req.tenant.id}/documents/${randomUUID()}.${ext(type)}`;
```

❌ Don't
```ts
storage.putObject({ Key: req.file.originalname, Body: req.file.buffer, ACL: 'public-read' }); // overwrite, path tricks, public
```

### 10. Verify payment webhooks with the raw body

A payment provider webhook (Stripe in this example) is trusted only after signature verification over the raw body. The webhook secret is referenced by name (server environment config), never written.

✅ Do
```ts
app.post('/api/webhooks/stripe', express.raw({ type: 'application/json' }), (req, res) => {
  const event = stripe.webhooks.constructEvent(req.body, req.header('stripe-signature')!, config.stripeWebhookSecret);
  // process idempotently by event.id
  res.sendStatus(200);
});
```

❌ Don't
```ts
app.post('/api/webhooks/stripe', express.json(), (req) => activatePlan(req.body.data.object)); // anyone can POST "paid"
```

Mount the raw-body route before the global `express.json()`, or exclude it. The webhook path and permission names in this file are examples.

### 11. Guard destructive operations by role and environment

Endpoints that reset, wipe, reverse or bulk-delete data get the strongest role, an explicit confirmation, an audit entry, and are tested only against a local or disposable test tenant.

✅ Do
```ts
router.post('/:id/reset', requirePermission('tenant:reset'), validateBody(confirmSchema('RESET_TENANT')), asyncHandler(controller.reset));
// service writes the audit entry (actor, tenant, time) before the reset runs
```

❌ Don't
```ts
// e2e suite calls the reset endpoint against staging "to start clean"
```

### 12. Keep PII, money and secrets out of logs and errors

National or tax ids, phones, emails, tokens, card data and amounts never appear in logs or error messages. See `logging-observability` and `customer-data-protection`. Secrets are referenced by name and location only.

✅ Do
```ts
req.log.info({ customerId: c.id }, 'customer created');
```

❌ Don't
```ts
req.log.info({ body: req.body }, 'customer created'); // id number, phone, address in plain text
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `Model.findById(req.params.id)` | Cross-tenant read | Tenant-scoped repository or plugin |
| Permission only in the frontend guard | API open to any logged-in user | `requirePermission` on the route |
| Raw body values in filters | `$ne`/`$gt` operator injection | Schema validation plus sanitizing |
| `Model.create(req.body)` | Client sets tenant, balance, role | Pick fields from the DTO |
| One global rate limit | Brute force on login and recovery codes | Strict limiter on auth routes |
| `cors()` with `*` | Any origin calls the API | Allowlist of your own origins |
| Webhook trusted without signature | Fake "paid" events | `constructEvent` on raw body |
| Upload keyed by original name | Overwrites, traversal, cross-tenant reads | Tenant prefix plus random key |
| Destructive route on GET or without audit | Accidental wipe, no trail | POST, confirm, role, audit |

## Review checklist

- [ ] Every query goes through the tenant mechanism; cross-tenant ids return 404.
- [ ] Route has a server-side permission check matching the module and role.
- [ ] Body and query validated by type; no `$where`; no raw objects in filters.
- [ ] No `req.body` spread into a model.
- [ ] Auth and recovery routes have a strict limiter.
- [ ] Token verified (not decoded); tenant claim matches; no token in URLs or logs.
- [ ] Uploads limited by size and detected type; tenant-prefixed random key; not public.
- [ ] Payment webhook verified with the raw body; processed idempotently.
- [ ] Destructive routes: role, confirmation, audit, never run against a real tenant.
- [ ] No PII, amounts or secrets in logs or error messages.

## Adapt to your repo

- The auth mechanism (JWT bearer or session cookie) and where it is verified.
- How the tenant reaches the API (header, token claim, subdomain or Origin).
- The permission model: role and module names, the middleware name.
- The validation library and any sanitizer in use.
- The rate limiter config, and whether auth routes have their own.
- Which origins need CORS access.
- The upload library, limits and storage key layout.
- The payment webhook route and secret name (name only).
- How support sessions are recorded.
- Which role may call destructive operations.
