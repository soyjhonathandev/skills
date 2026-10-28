---
name: angular-testing
description: Use when writing or reviewing unit and component tests in an Angular app (TestBed, HttpTestingController, NgRx MockStore, harnesses, fakeAsync).
applies_to: [angular-app]
---

# Skill: Angular Testing

> TestBed with the repo's runner, HttpTestingController for every HTTP call, MockStore for NgRx, harnesses or the DOM for ng-bootstrap widgets. Tests protect contracts that matter (money, stock, tenant, permissions); the `test-audit` gate decides whether a test is worth adding.

## When this applies

- Writing a spec for a component, service, effect, selector, pipe, guard or interceptor.
- Frontend work running in parallel with API work: it codes against the agreed contract with HttpTestingController mocks and fixtures and never waits for the API to merge.
- Fixing a flaky spec.

Before writing a test, answer the five questions in `test-audit`. A reasonable retention bar for a business app: auth and tenant handoff, money math and display, payments, inventory decrement and batch moves, receivable and payable balances.

## Rules

### 1. Every HTTP call in a test goes through `HttpClientTestingModule`

Assert the method, the URL under the API base and the body against the contract DTO.

✅ Do
```ts
it('posts the split to inventory/split-batch', () => {
  service.splitBatch({ batchId: 'b1', locationId: 'loc-warehouse', quantity: 4 }).subscribe((r) => (result = r));
  const req = httpMock.expectOne(`${env.apiUrl}/inventory/split-batch`);
  expect(req.request.method).toBe('POST');
  expect(req.request.body).toEqual({ batchId: 'b1', locationId: 'loc-warehouse', quantity: 4 });
  req.flush(splitBatchResponseFixture);
  expect(result.length).toBe(2);
});
afterEach(() => httpMock.verify());
```

❌ Don't
```ts
spyOn(http, 'post').and.returnValue(of({})); // asserts nothing about URL, body or contract
```

### 2. Fixtures are fictitious and typed against the contract DTO

A demo tenant such as `demo-store`, invented customers, no real tax IDs, phone numbers or amounts copied from production. Keep fixtures next to the feature or in the repo's fixture folder.

✅ Do
```ts
export const invoiceFixture: InvoiceDto = {
  id: 'inv-1', kind: 'receivable', customer: { name: 'Demo Customer', taxId: 'TEST-0000' },
  balance: { amountMinor: 1500, currency: 'USD' }, dueDate: '2026-11-15',
};
```

❌ Don't
```ts
const inv = { customer: 'Real customer copied from a support ticket', balance: 15.0 }; // real data, float, untyped
```

### 3. Effects: test with `provideMockActions` and marbles or plain subscriptions

✅ Do
```ts
actions$ = of(batchSplitRequested({ batchId: 'b1', locationId: 'l1', quantity: 2 }));
api.splitBatch.and.returnValue(throwError(() => apiError('INSUFFICIENT_STOCK')));
effects.splitBatch$.subscribe((a) => expect(a).toEqual(batchSplitFailed({ error: apiError('INSUFFICIENT_STOCK') })));
```

❌ Don't
```ts
TestBed.configureTestingModule({ imports: [StoreModule.forRoot(reducers), EffectsModule.forRoot([...all])] }); // the whole app per spec
```

### 4. Components that read the store use `MockStore` with overridden selectors

✅ Do
```ts
providers: [provideMockStore({ selectors: [{ selector: selectActiveRegisterSummary, value: registerSummaryFixture }] })]
```

❌ Don't
```ts
store.setState({ register: { entities: {...}, ids: [...], loading: false, /* 40 more fields */ } }); // couples to state shape
```

### 5. Selectors and reducers are pure: test them without TestBed

✅ Do
```ts
expect(selectBatchesByLocation('loc-front').projector([batchA, batchB])).toEqual([batchB]);
```

❌ Don't
```ts
TestBed.configureTestingModule({ ... }); fixture.detectChanges(); // to test a filter function
```

### 6. Interact with ng-bootstrap through the DOM or a harness, not private fields

✅ Do
```ts
const confirm = fixture.debugElement.query(By.css('[data-testid="close-register-confirm"]'));
confirm.nativeElement.click();
fixture.detectChanges();
expect(store.dispatch).toHaveBeenCalledWith(closeRegisterConfirmed({ counts: countsFixture }));
```

❌ Don't
```ts
component['modalRef'].close(true); // private API; passes even if the button is gone
```

Adding a `data-testid` touches templates: list it in the work plan when someone else owns the template (see `e2e-testing`).

### 7. Time and debounce use `fakeAsync` + `tick`, never real waits

✅ Do
```ts
it('checks the tax ID after debounce', fakeAsync(() => {
  control.setValue('TEST-0000');
  tick(400);
  httpMock.expectOne((r) => r.url.endsWith('/customers/check-field')).flush({ exists: false });
  expect(control.valid).toBeTrue();
}));
```

❌ Don't
```ts
it('checks', (done) => { setTimeout(() => { expect(...); done(); }, 500); }); // slow, flaky
```

### 8. Test money display and parsing at the boundary with explicit locale cases

✅ Do
```ts
it.each`
  input         | currency | minor
  ${'1.234,56'} | ${'EUR'} | ${123456}
  ${'0,29'}     | ${'EUR'} | ${29}
`('parses $input', ({ input, currency, minor }) => expect(parseMoneyToMinor(input, currency)).toBe(minor));
```

❌ Don't
```ts
expect(format(1234.56)).toBeTruthy(); // asserts nothing
```

(`it.each` is Jest syntax; with Jasmine write one `it` per case. Use whichever runner the repo has.)

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `spyOn(http, ...)` instead of HttpTestingController | Contract drift passes | `expectOne` on URL, method, body |
| Importing the real root store in specs | Slow, brittle, order-dependent | MockStore and selector overrides |
| Real tenant or customer data in fixtures | Data leak into git | A demo tenant and invented values |
| `setTimeout` waits | Flaky in CI | `fakeAsync` and `tick` |
| Snapshot of a whole page | Breaks on every copy change, protects nothing | Assert the contract the screen depends on |
| Tests for getters and trivial templates | Noise, slows the suite | Apply the `test-audit` gate |

## Review checklist

- [ ] The test answers the five `test-audit` questions; it guards a retention-bar contract or a real regression.
- [ ] HTTP is asserted with HttpTestingController and `httpMock.verify()` runs after each spec.
- [ ] Fixtures are fictitious and typed with the contract DTO.
- [ ] Store-reading components use MockStore.
- [ ] No real timers; `fakeAsync` for debounce.
- [ ] New `data-testid` attributes are listed in the work plan when the template belongs to someone else.

## Adapt to your repo

- Find the runner (Karma + Jasmine, the long-time CLI default, or Jest) and its config file.
- Find the test script name in `package.json` and how CI runs it.
- Check whether Angular Testing Library or CDK harnesses are installed.
- Find the fixture folder convention, if any.
- Check current coverage and whether a threshold is enforced.
