---
name: multi-tenancy
description: Use when code in a multi-tenant SaaS reads or writes tenant data, resolves the tenant from the subdomain, adds an endpoint or collection, or writes tests that must prove one tenant cannot see another.
applies_to: [angular-app, express-api]
---

# Skill: Multi-Tenancy

> One customer per subdomain, one tenant per request, one scoping mechanism for every query, and a test that proves isolation.

## When this applies

- Any new or changed Express route, service or Mongoose model that touches business data (orders, invoices, payments, accounts, inventory, customers).
- Angular code that reads the hostname, handles a login handoff between hosts, or attaches tenant context in the HttpInterceptor.
- socket.io rooms and events (a push must never reach another tenant).
- Background jobs, exports and AI endpoints that read tenant data.
- Security and architecture reviews: tenant scoping is a blocking concern.

The examples assume the app runs on `<tenant>.example.com` and the API learns the tenant from the request; adapt to how your product actually routes tenants.

## Rules

### 1. Resolve the tenant once, at the edge, into `req.tenant`
A tenant middleware runs before every business router and sets `req.tenant = { id, subdomain }`. Controllers and services read it from there and nowhere else. Whatever the source (header, token claim, Origin/subdomain), it must be checked against the authenticated user.

✅ Do
```ts
// tenant middleware, mounted before the /api business routers
export async function resolveTenant(req, res, next) {
  const subdomain = readTenantSource(req); // header | token claim | Origin
  const tenant = await Tenant.findOne({ subdomain }).select('_id subdomain').lean();
  if (!tenant || String(tenant._id) !== String(req.user.tenantId)) {
    return next(new HttpError(403, 'TENANT_MISMATCH', 'Tenant does not match the session'));
  }
  req.tenant = { id: tenant._id, subdomain: tenant.subdomain };
  next();
}
```
❌ Don't
```ts
router.get('/orders', async (req, res) => {
  const orders = await Order.find({ tenantId: req.query.tenantId }); // client chooses the tenant
  res.json(orders);
});
```

### 2. Scope every Mongo query through one mechanism, never by hand
Pick one: a Mongoose plugin that injects `tenantId` into every query and save, or a repository base class that every service uses. Hand-written `{ tenantId }` filters are forgotten on the one query that matters. See `mongodb-mongoose`.

✅ Do
```ts
// tenant-scope plugin (one mechanism; use whichever the repo already has)
export function tenantScope(schema) {
  schema.add({ tenantId: { type: Schema.Types.ObjectId, required: true, index: true } });
  for (const op of ['find', 'findOne', 'countDocuments', 'updateOne', 'updateMany', 'deleteOne', 'deleteMany', 'findOneAndUpdate']) {
    schema.pre(op, function () {
      const tenantId = this.getOptions().tenantId;
      if (!tenantId) throw new Error('tenantId option missing on ' + op);
      this.where({ tenantId });
    });
  }
  schema.pre('aggregate', function () {
    const tenantId = this.options.tenantId;
    if (!tenantId) throw new Error('tenantId option missing on aggregate');
    this.pipeline().unshift({ $match: { tenantId } });
  });
}

// service
const lines = await OrderLine.find({ productId }, null, { tenantId: req.tenant.id }).lean();
```
❌ Don't
```ts
const lines = await OrderLine.find({ productId }).lean(); // every tenant's lines for that product id
const total = await Order.aggregate([{ $group: { _id: null, sum: { $sum: '$totalMinor' } } }]); // all tenants
```

### 3. Write the tenant on create from the server, never from the body
Mass assignment of `tenantId` lets one customer write into another. Strip it from input and set it from `req.tenant`.

✅ Do
```ts
const { tenantId, ...input } = req.body as CreateExpenseDto & { tenantId?: unknown };
await Expense.create({ ...pick(input, ['name', 'amountMinor', 'currency', 'dueDate']), tenantId: req.tenant.id });
```
❌ Don't
```ts
await Expense.create(req.body); // body may carry tenantId, _id, paid flags
```

### 4. Load by id AND tenant, and answer 404 for another tenant's id
A `findById` with no tenant filter leaks existence and data. Return 404, not 403, so ids of other tenants are not confirmed.

✅ Do
```ts
const invoice = await Invoice.findOne({ _id: req.params.id }, null, { tenantId: req.tenant.id });
if (!invoice) throw new HttpError(404, 'INVOICE_NOT_FOUND', 'Invoice not found');
```
❌ Don't
```ts
const invoice = await Invoice.findById(req.params.id);
if (String(invoice.tenantId) !== String(req.tenant.id)) return res.status(403).end();
```

### 5. Keep socket.io traffic inside a tenant room
Join sockets to `tenant:<id>` after the handshake is authenticated and emit only to that room. See `realtime-socketio`.

✅ Do
```ts
io.use(authenticateSocket); // sets socket.data.tenantId from the verified session
io.on('connection', (socket) => socket.join(`tenant:${socket.data.tenantId}`));
io.to(`tenant:${req.tenant.id}`).emit('order:updated', { orderId });
```
❌ Don't
```ts
io.emit('order:updated', { orderId }); // every connected customer receives it
socket.join(socket.handshake.query.tenant); // client picks its room
```

### 6. In Angular, derive the tenant from the hostname in one service
One injectable owns the hostname parsing, the "does this tenant exist" check and the redirect to a tenant-not-found page. Components never parse `window.location`.

✅ Do
```ts
@Injectable({ providedIn: 'root' })
export class TenantService {
  readonly subdomain = window.location.hostname.split('.')[0];
  constructor(private http: HttpClient, private router: Router) {}

  verify(): Observable<boolean> {
    return this.http.get<{ exists: boolean }>(`${environment.API_URL}/tenants/current`).pipe(
      map((r) => r.exists),
      tap((ok) => { if (!ok) this.router.navigate(['/tenant-not-found']); }),
    );
  }
}
```
❌ Don't
```ts
ngOnInit(): void {
  const tenant = location.host.replace('.example.com', ''); // parsed again in every component
  this.http.get(`${environment.API_URL}/orders?tenant=${tenant}`).subscribe(/* ... */);
}
```

### 7. Attach tenant context only in the HttpInterceptor
If the API needs a header or token for the tenant, one interceptor adds it to every API call. Services do not add it by hand.

✅ Do
```ts
@Injectable()
export class ApiContextInterceptor implements HttpInterceptor {
  constructor(private tenant: TenantService) {}
  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    if (!req.url.startsWith(environment.API_URL)) return next.handle(req);
    return next.handle(req.clone({ setHeaders: tenantHeaders(this.tenant) }));
  }
}
```
❌ Don't
```ts
this.http.get(url, { headers: { tenant: this.tenant.subdomain } }); // one service forgets, the request is unscoped
```

### 8. Every new endpoint ships with an isolation test
The test seeds two fictitious tenants (`tenant-a` and `tenant-b`), acts as one, and proves it cannot read, update or delete the other's data. Treat this as a test worth keeping in any test audit (`test-audit`).

✅ Do
```ts
it('does not return another tenant invoice', async () => {
  const other = await seedInvoice({ tenant: 'tenant-b' });
  const res = await request(app).get(`/api/invoices/${other._id}`).set(authAs('tenant-a'));
  expect(res.status).toBe(404);
});
```
❌ Don't
```ts
it('returns the invoice', async () => {
  const invoice = await seedInvoice({ tenant: 'tenant-a' });
  await request(app).get(`/api/invoices/${invoice._id}`).set(authAs('tenant-a')).expect(200);
}); // single-tenant fixture proves nothing about isolation
```

### 9. Treat tenant-wide reset and reversal operations as destructive
Operations that wipe or rewrite a whole tenant's records (reset, bulk reverse, bulk delete) run only against a local or disposable test tenant, never staging or production, and never from a test that shares a database with another parallel run.

✅ Do
```ts
await request(app).post('/api/admin/reset-inventory').set(authAs('tenant-a')); // disposable per-run test database
```
❌ Don't
```ts
await axios.post(`${STAGING_API}/admin/reset-tenant`, {}, auth); // shared tenant data gone
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `tenantId` from query or body | Any user can read or write another customer | `req.tenant` set by middleware |
| Manual `{ tenantId }` per query | One forgotten filter is a data leak | Plugin or repository base, rule 2 |
| `findById` then compare tenant | Leaks existence, easy to skip the compare | `findOne({ _id }, null, { tenantId })` |
| Unscoped `aggregate` in reports | Summaries mix customers | Plugin prepends `$match` on `tenantId` |
| `io.emit` to all sockets | Realtime leak across tenants | Tenant rooms |
| Hostname parsed in components | Inconsistent, untestable | `TenantService` |
| Single-tenant test fixtures | Isolation never exercised | Two-tenant isolation test |
| Real subdomains in fixtures or logs | Exposes customers | Fictitious tenants (`customer-data-protection`) |

## Review checklist

- [ ] Tenant comes from `req.tenant`, never from params, query or body.
- [ ] Every new model uses the tenant-scope mechanism; no hand-written tenant filters.
- [ ] Aggregations, `countDocuments`, `distinct` and bulk writes are scoped too.
- [ ] Lookups by id return 404 for another tenant's id.
- [ ] `tenantId` is stripped from input on create and update.
- [ ] socket.io emits go to the tenant room only.
- [ ] Angular reads the tenant through `TenantService`; the interceptor attaches context.
- [ ] A two-tenant isolation test exists for each new endpoint.
- [ ] No tenant-wide reset or reversal outside a local or disposable tenant.
- [ ] Fixtures and logs use fictitious tenants only.

## Adapt to your repo

- How the API learns the tenant (header, token claim or Origin), and its name.
- Where tenant documents live and their key field (subdomain, slug, id).
- One database with a `tenantId` per document, or database per tenant.
- The existing scoping mechanism (plugin, repository base or per-query pattern), or the plan to introduce one.
- The tenant existence check on the client: endpoint, response shape, and the guard or resolver that calls it.
- How a login handoff between hosts passes the session (query token, cookie) and where it is stored.
- The HttpInterceptor class names and what each one attaches.
- How socket.io authenticates and whether rooms are per tenant today.
- How staff support logins cross tenants, so their rules are written down.
