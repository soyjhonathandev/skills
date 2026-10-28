---
name: api-contract
description: Use when a change crosses the frontend app and the API, when you add or change an endpoint, DTO, error code or socket event, or when a reviewer checks both sides against a pinned contract.
applies_to: [angular-app, express-api]
---

# Skill: API Contract

> Write the contract first, pin it, and make the Angular service and the Express route cite the same DTO. Change it only in ways old clients survive.

## When this applies

- Cross-stack features where an `api` track and an `app` track start together against the pinned contract.
- Any new endpoint, any change to a request or response body, status code, error code, pagination or socket.io event.
- Contract review (the integration check across both sides) and plan review (blocks drift from the pinned contract).

Related: naming and REST shape in `api-design`, tenant scope in `multi-tenancy`, amounts in `money-and-currency`.

## Rules

### 1. Write the contract block before any code
Every endpoint in a feature has one block with all fields filled. A blank field is a planning gap, not an implementation choice.

✅ Do
````md
### POST /api/inventory/transfers
- Auth: session required; role with inventory write permission
- Tenant scope: req.tenant; both locations must belong to it
- Request DTO: CreateTransferDto { itemId: string; fromLocationId: string; toLocationId: string; qty: number; note?: string }
- Response DTO: 201 TransferDto { id: string; itemId: string; fromLocationId: string; toLocationId: string; qty: number; createdAt: string; userId: string }
- Errors: 400 VALIDATION_FAILED, 404 LOCATION_NOT_FOUND, 409 INSUFFICIENT_STOCK
- Pagination: n/a
- Realtime: emits `inventory:updated` { itemId } to tenant room
````
❌ Don't
```md
- add endpoint to move stock between locations (details during implementation)
```

### 2. Pin it, and treat the pin as immutable
The contract lives in the feature's contract file, pinned by a hash (or a commit) recorded with it. Tracks code against the pinned text; a change goes back through the planner and produces a new pin. Plan review blocks any diff that disagrees with the pin.

✅ Do
```ts
// app track, written while the api track is still open
it('posts the transfer as pinned', () => {
  service.createTransfer(dto).subscribe();
  const req = httpMock.expectOne(`${environment.API_URL}/inventory/transfers`);
  expect(req.request.body).toEqual(dto); // CreateTransferDto from the pin
  req.flush(transferFixture);
});
```
❌ Don't
```ts
// api track renames a field because it "reads better"; the app track never hears about it
res.status(201).json({ id, item: itemId, from, to, quantity: qty });
```

### 3. Both sides cite the same DTO name
The Express validator, the controller response and the Angular service use the DTO names from the contract. The DTO lives either in a shared package or as mirrored interfaces in each repo; if mirrored, the file header names the contract.

✅ Do
```ts
// app: inventory-transfer.service.ts
createTransfer(body: CreateTransferDto): Observable<TransferDto> {
  return this.http.post<TransferDto>(`${environment.API_URL}/inventory/transfers`, body);
}
// api: transfers.controller
export async function create(req: Request<{}, TransferDto, CreateTransferDto>, res: Response<TransferDto>) { /* ... */ }
```
❌ Don't
```ts
createTransfer(body: any): Observable<any> { return this.http.post(url, body); }
```

### 4. Use one error shape and named codes
For new endpoints, unless the repo already has a shape: `{ "error": { "code", "message", "details", "requestId" } }`, codes in UPPER_SNAKE. The app branches on `code`, never on `message` text.

✅ Do
```ts
// api
throw new HttpError(409, 'INSUFFICIENT_STOCK', 'Not enough stock in the source location', [{ itemId, available }]);
// app
catchError((e: HttpErrorResponse) => e.error?.error?.code === 'INSUFFICIENT_STOCK' ? of(showStockWarning()) : throwError(e)) // match your RxJS major's throwError signature
```
❌ Don't
```ts
res.status(500).send('Not enough stock'); // app has to match message text
if (err.error.includes('stock')) { /* ... */ }
```

### 5. State pagination in the contract
For new list endpoints, unless existing paginated endpoints already set a shape: query `?page=1&pageSize=50`, response `{ items, page, pageSize, total }`, with a server-enforced max page size.

✅ Do
```ts
export interface Page<T> { items: T[]; page: number; pageSize: number; total: number; }
listCustomers(page = 1, pageSize = 50): Observable<Page<CustomerDto>> { /* ... */ }
```
❌ Don't
```ts
router.get('/customers', async (req, res) => res.json(await Customer.find(...))); // 20,000 rows on a phone
```

### 6. Money and dates have one wire format
Amounts travel as `{ amountMinor, currency }` (or the repo's confirmed representation) with the rate snapshot where relevant. Dates travel as ISO 8601 strings in UTC. No formatted strings on the wire.

✅ Do
```json
{ "total": { "amountMinor": 125000, "currency": "EUR" }, "rate": { "rate": "0.92", "source": "FX_PROVIDER_USD_EUR", "date": "2026-10-21" }, "createdAt": "2026-10-21T14:05:00.000Z" }
```
❌ Don't
```json
{ "total": "€1.250,00", "date": "21/10/2026" }
```

### 7. Only additive changes are non-breaking
Adding an optional request field or a new response field is safe. Removing or renaming a field, changing a type, tightening validation, changing a status code or error code, or changing pagination is breaking: ship a new route or version, keep the old one, and record a deprecation date.

✅ Do
```ts
// add: TransferDto gains optional `reason?: string`; old clients ignore it
router.post('/inventory/transfers', validate(CreateTransferDto), create);
router.post('/v2/inventory/transfers', validate(CreateTransferDtoV2), createV2); // breaking shape, new path
```
❌ Don't
```ts
// qty becomes { value, unit } in place; every deployed app breaks on next release
```

### 8. Socket events are part of the contract
Event name, payload DTO and room are pinned like an endpoint. A payload change follows rule 7.

✅ Do
```ts
export interface InvoiceUpdatedEvent { invoiceId: string; status: 'open' | 'closed'; at: string; }
io.to(`tenant:${tenantId}`).emit('invoice:updated', payload as InvoiceUpdatedEvent);
```
❌ Don't
```ts
io.to(room).emit('update', invoice.toObject()); // whole document, unnamed shape, internal fields leak
```

### 9. The app track never waits for the api track to merge
It codes against the pin with HttpTestingController mocks and fixtures built from the response DTO. Integration happens last, in merge order `api`, then the frontend apps, then `e2e`.

✅ Do
```ts
export const transferFixture: TransferDto = { id: 't1', itemId: 'i1', fromLocationId: 'warehouse', toLocationId: 'storefront', qty: 6, createdAt: '2026-10-21T14:05:00.000Z', userId: 'u1' };
```
❌ Don't
```ts
// app track pauses: "waiting for the API PR to land so I can see the real response"
```

### 10. Shared files belong to one track
The shared DTO file, the Express router index and the Angular routing module are owned by exactly one track named in the contract. Other tracks request changes through it.

✅ Do
```md
- Shared files: `<dto location>` (owner: api track), Angular routing module (owner: app track)
```
❌ Don't
```md
- both tracks edit the DTO file "as needed"
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Contract written after the code | Tracks disagree at integration | Contract block first, pinned |
| `any` in services or controllers | Drift compiles silently | Named DTOs on both sides |
| Branching on error message text | Breaks on wording or language change | Error `code` |
| In-place field rename | Deployed clients break | New field or new version |
| Whole Mongoose document as response | Leaks internals, couples clients to schema | Response DTO mapping |
| Formatted money or dates on the wire | Clients cannot compute | Numbers, currency, ISO dates |
| Undocumented socket payloads | Silent breakage on push | Pinned event DTOs |

## Review checklist

- [ ] Every endpoint has a complete contract block (method, path, auth, tenant scope, request DTO, response DTO, errors, pagination).
- [ ] The diff matches the pinned contract; the pin was checked.
- [ ] Angular service, Express route and validator cite the same DTO names.
- [ ] Error responses use the agreed shape and named codes.
- [ ] List endpoints are paginated with a server max.
- [ ] Money and dates use the wire formats in rule 6.
- [ ] No breaking change without a new route or version and a deprecation note.
- [ ] Socket events have pinned names and payload DTOs.
- [ ] Shared files have one owner track.

## Adapt to your repo

- Where DTOs live today: shared package, mirrored interfaces, or none.
- The current error response shape and status code conventions.
- The pagination shape of existing list endpoints.
- The request validation library on the API.
- Whether any versioning exists in the API paths.
- The auth mechanism and how permissions per role are named.
- Date and money wire formats in existing responses.
- Whether an OpenAPI spec or generated client exists.
- The RxJS major in the app, which decides the `throwError` signature in error-handling code.
