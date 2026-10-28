---
name: architecture
description: Use at the start of every session and before planning any change, to locate the code, the bounded context and the side (frontend app or API) a task lives in, and to keep layer boundaries intact.
applies_to: [angular-app, express-api]
---

# Skill: Architecture

> The map of the project's repos, how a request travels from a route to the database and back, and which bounded context owns what. Keep the map in this skill (or a doc it points to) and keep it current.

## When this applies

- Every session: read it with `good-practices` before the stack skills.
- Planning parallel work: pick the side, the bounded context and the files per track from here.
- Architecture review checks layer boundaries against the rules below.

## Repo map

Fill these in once per project from the real source, and mark anything you inferred (from a bundle, traffic or docs) as `(inferred)` until you have read the code.

### Which side am I on

| Question | frontend app | API |
|---|---|---|
| Kind | angular-app | express-api |
| Served at | the app host | the API host and base path |
| Owns | screens, NgRx state, forms, exports, socket client | REST, validation, tenant scoping, database, socket server, third-party calls |
| Stack | Angular version, module style, state library, UI kit, chart and export libraries | Express version, middleware, database and ODM, realtime library |
| Root folder | path | path |

If a task changes a payload, it touches both sides: plan it contract-first (`api-contract`).

### Frontend: top-level routes

List the lazy modules (`loadChildren`) and their top-level paths, then group child routes by the bounded context that owns them:

| Area | Child routes | Bounded context |
|---|---|---|
| Orders | `orders`, `orders/:id`, `returns/:id`, `discounts` | `orders` |
| Inventory | `inventory`, `inventory/entries`, `inventory/transfers` | `inventory` |
| Accounts | `accounts`, `accounts/:id/payments` | `accounts` |
| Settings | `settings`, `users`, `plans` | `billing-and-plans`, `tenancy-and-auth` |
| Auth | `login`, `forgot-password` | `tenancy-and-auth` |

Record the environment object keys the app reads (never their values).

### API: resources

| Resource | Notable endpoints | Bounded context |
|---|---|---|
| `auth`, `tenants`, `users` | sign-in, session, user management | `tenancy-and-auth` |
| `orders`, `discounts` | create, return, list | `orders` |
| `inventory` | add batch, split batch, transfer between locations | `inventory` |
| `accounts`, `payments` | transfer, deposit, partial payment | `accounts` |
| destructive admin routes | reset data, reverse an order | destructive, local test tenant only |

Record the folder layout (routes, controllers, services, models, middleware) and the entry file.

### Bounded contexts
Keep one doc per context, named after it (`tenancy-and-auth`, `orders`, `inventory`, `accounts`, `invoices`, `billing-and-plans`, ...), and link each from the tables above.

## Rules

### 1. Follow the request lifecycle; do not skip layers
Angular route (lazy module) -> component -> NgRx store or service -> HttpClient through the HttpInterceptor -> API base path -> middleware (rate limit, CORS, auth, tenant, validation) -> controller -> service -> Mongoose model -> MongoDB, with socket.io pushing changes back to the tenant room.

✅ Do
```ts
// app: component -> store; effect -> service -> HttpClient
this.store.dispatch(InvoiceActions.close({ dto }));
// api: router -> controller -> service -> model
router.post('/invoices/:id/close', auth, tenant, validate(CloseInvoiceDto), invoiceController.close);
```
❌ Don't
```ts
// component calls HttpClient directly and the route handler queries Mongo directly
this.http.post(`${environment.API_URL}/invoices/${id}/close`, body).subscribe();
router.post('/invoices/:id/close', async (req, res) => res.json(await Invoice.create(req.body)));
```

### 2. Keep a feature inside its bounded context
A change to closing an invoice lives in the `invoices` module (app) and the invoices router, service and model (api). Cross-context effects (an order moving inventory, an account balance and a receivable) go through the owning context's service, never by writing another context's collection directly.

✅ Do
```ts
await inventoryService.decrementForOrder(tenantId, orderLines, session);
await accountsService.createReceivable(tenantId, order, session);
```
❌ Don't
```ts
await InventoryBatch.updateOne({ _id }, { $inc: { qty: -2 } }); // from inside the orders service
```

### 3. One owner per shared file in parallel work
`app.module.ts`, the root routing module, NgRx root reducers, the Express entry and router index, shared DTOs, `package.json` and lockfiles belong to one track named in the plan.

✅ Do
```md
Shared files: app routing module (owner: app track); api router index (owner: api track)
```
❌ Don't
```md
Both tracks add their route to the router index "when they get there".
```

### 4. New feature modules are lazy
A new top-level area in the app is a module loaded with `loadChildren`, keeping the initial bundle small.

✅ Do
```ts
{ path: 'transfers', loadChildren: () => import('./transfers/transfers.module').then((m) => m.TransfersModule) }
```
❌ Don't
```ts
@NgModule({ imports: [BrowserModule, TransfersModule /* eager in AppModule */] })
```

### 5. Update the map when the map changes
A PR that adds a route, a resource, a collection or a bounded context updates this map and the matching context doc in the same PR.

✅ Do
```text
:book: architecture: add transfers route and inventory transfers resource
```
❌ Don't
```text
// map left stale; the next agent plans against routes that moved
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Component calls HttpClient | Untestable, duplicated calls | Service or NgRx effect |
| Route handler queries Mongo | No tenant scope, no reuse | Controller -> service -> model |
| Writing another context's collection | Hidden coupling, broken invariants | Call the owning service |
| Eager feature module | Bigger first load on phones | `loadChildren` |
| Two tracks editing the router index | Merge conflicts, lost routes | One owner track |
| Stale map | Wrong plans | Update in the same PR |

## Review checklist

- [ ] The change sits in one side and one bounded context, or is planned contract-first.
- [ ] No layer is skipped on either side.
- [ ] Cross-context effects go through the owning service.
- [ ] Shared files have one owner track.
- [ ] New feature areas are lazy modules.
- [ ] This map and the context doc are updated if routes, resources or collections changed.

## Adapt to your repo

- Root folders of each repo and their trunk branches.
- The real lazy module names behind each top-level route.
- The API folder layout and entry file.
- The middleware order on the API.
- The Express and Mongoose versions.
- The collections per bounded context.
- Where socket.io is initialized on each side and its event names.
- Whether a shared DTO package or monorepo tooling exists.
- Any secondary frontend (a sign-up app, an admin app) and the API endpoints it calls.
