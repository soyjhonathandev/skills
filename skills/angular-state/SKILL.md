---
name: angular-state
description: Use when deciding where client state lives in an Angular app, or when adding NgRx actions, reducers, effects, selectors or entity adapters.
applies_to: [angular-app]
---

# Skill: Angular State

> NgRx for state shared across screens or pushed by the server; a service with a `BehaviorSubject` for feature-local state; component fields for view-only state. The API stays the source of truth for money, stock and balances.

## When this applies

- Adding a feature slice (inventory items and batches, the active register session, the cart, receivables and payables lists, today's exchange rate).
- Wiring realtime (socket.io or similar) events into the store (see `realtime-socketio`).
- Choosing between NgRx and a plain service.
- Editing root reducers or the root `StoreModule.forRoot` config: a shared file owned by one stream of work when work runs in parallel.

Where state lives, first match wins:

1. View-only state (an open modal, a selected tab, a filter text box): component field. On Angular 17+, a component-local signal (see `angular-upgrade`).
2. State one feature uses and nothing else listens to (a form wizard step in onboarding): a feature-provided service with a `BehaviorSubject`.
3. State several screens read, or that the server pushes (active register session, exchange rate, inventory stock, open orders): NgRx feature slice.
4. State that must survive a reload or be shareable (filters on an order history, the date range on a daily report): router query params.

## Rules

### 1. One feature slice per lazy module, registered with `StoreModule.forFeature`

✅ Do
```ts
@NgModule({
  imports: [
    StoreModule.forFeature(inventoryFeatureKey, inventoryReducer),
    EffectsModule.forFeature([InventoryEffects]),
  ],
})
export class InventoryModule {}
```

❌ Don't
```ts
// app.module.ts: every feature reducer in the root, loaded on first paint
StoreModule.forRoot({ inventory: inventoryReducer, orders: ordersReducer, invoices: invoicesReducer })
```

### 2. Actions are events named `[Source] Event`, created with `createAction` and `props`

✅ Do
```ts
export const batchSplitRequested = createAction(
  '[Batch Detail] Split Requested',
  props<{ batchId: string; locationId: string; quantity: number }>(),
);
export const batchSplitSucceeded = createAction('[Inventory API] Batch Split Succeeded', props<{ batches: InventoryBatch[] }>());
export const batchSplitFailed = createAction('[Inventory API] Batch Split Failed', props<{ error: ApiError }>());
```

❌ Don't
```ts
export const setData = createAction('SET_DATA', props<{ data: any }>()); // no source, no meaning, untyped
```

### 3. Collections use `@ngrx/entity`

Inventory items, batches, invoices and orders are id-keyed collections.

✅ Do
```ts
export const adapter = createEntityAdapter<InventoryBatch>({ selectId: (b) => b.id });
export const inventoryReducer = createReducer(
  adapter.getInitialState({ loading: false, error: null as ApiError | null }),
  on(batchSplitSucceeded, (s, { batches }) => adapter.upsertMany(batches, { ...s, loading: false })),
);
```

❌ Don't
```ts
on(batchSplitSucceeded, (s, { batches }) => ({ ...s, list: [...s.list.filter(...), ...batches] })) // hand-rolled, O(n) lookups
```

### 4. Side effects only in effects; reducers stay pure

✅ Do
```ts
splitBatch$ = createEffect(() => this.actions$.pipe(
  ofType(batchSplitRequested),
  concatMap(({ batchId, locationId, quantity }) =>
    this.inventoryApi.splitBatch({ batchId, locationId, quantity }).pipe(
      map((batches) => batchSplitSucceeded({ batches })),
      catchError((error) => of(batchSplitFailed({ error }))),
    )),
));
constructor(private actions$: Actions, private inventoryApi: InventoryApiService) {}
```

❌ Don't
```ts
on(batchSplitRequested, (s, a) => { this.http.post(...); return s; }) // HTTP inside a reducer
```

### 5. Pick the flattening operator on purpose

`concatMap` for money and stock writes (orders, payments, batch splits, transfers) so they run in order; `switchMap` for reads that a newer request replaces (search, filters); `exhaustMap` for "close the register" and login so double clicks do nothing.

✅ Do
```ts
closeRegister$ = createEffect(() => this.actions$.pipe(ofType(closeRegisterClicked), exhaustMap(({ counts }) => this.api.close(counts).pipe(...))));
```

❌ Don't
```ts
ofType(recordPayment), switchMap(...) // a second payment cancels the first request mid-flight
```

### 6. Errors are state, caught inside the inner observable

A `catchError` on the outer pipe kills the effect for the rest of the session.

✅ Do
```ts
switchMap((q) => this.api.search(q).pipe(map(found), catchError((e) => of(searchFailed({ error: e })))))
```

❌ Don't
```ts
switchMap((q) => this.api.search(q)), map(found), catchError(...) // effect completes after the first error
```

### 7. Components read through memoized selectors only

✅ Do
```ts
export const selectBatchesByLocation = (locationId: string) =>
  createSelector(selectAllBatches, (batches) => batches.filter((b) => b.locationId === locationId));
```

❌ Don't
```ts
this.store.subscribe((s: any) => (this.batches = s.inventory.entities)); // reaches into state shape, untyped
```

### 8. The store mirrors the server; it never computes money or stock

The API decides the new balance after a payment, the remaining stock after an order and the difference at the end-of-day cash close. The store saves what the API returned.

✅ Do
```ts
on(paymentRecorded, (s, { invoice }) => adapter.upsertOne(invoice, s)) // invoice.balance comes from the API
```

❌ Don't
```ts
on(paymentRecorded, (s, { amount }) => ({ ...s, balance: s.balance - amount })) // client-side ledger
```

### 9. A service with a subject is enough for feature-local state

✅ Do
```ts
@Injectable() // provided in OnboardingModule only
export class OnboardingWizardState {
  private step$ = new BehaviorSubject<WizardStep>('business');
  readonly step = this.step$.asObservable();
  next(step: WizardStep): void { this.step$.next(step); }
}
```

❌ Don't
```ts
// a full actions/reducer/effects/selectors set for a three-step wizard nobody else reads
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Client-side balance or stock arithmetic | Drifts from the server, wrong cash close | Upsert the API response |
| `switchMap` on writes | Cancels an order or payment mid-flight | `concatMap` or `exhaustMap` |
| Outer `catchError` in effects | Effect dies after one error | Catch inside the inner pipe |
| `any`-typed actions | Contract drift invisible | `props<{...}>()` with DTO types |
| Root reducer for a lazy feature | Bigger main bundle, shared-file conflicts | `forFeature` in the lazy module |
| Same socket event dispatched from several components | Duplicate updates | One socket effect or service per event |

## Review checklist

- [ ] The decision order above was followed; NgRx is not used for view-only state.
- [ ] Actions follow `[Source] Event`, typed with `props`.
- [ ] Writes use `concatMap` or `exhaustMap`; reads use `switchMap`.
- [ ] `catchError` is inside the inner observable.
- [ ] Money, stock and balances come from the API, never computed in a reducer.
- [ ] Root store files are edited only by the owning stream of work.

## Adapt to your repo

- Check the NgRx version. The examples use `createAction`/`createReducer`/`createEffect`; older class-based actions may remain.
- Check whether `@ngrx/entity`, `@ngrx/router-store` and `@ngrx/store-devtools` are installed.
- Find the file layout of a slice (`+state/`, `store/`, one file per kind).
- List which features use NgRx and which use services with subjects today.
- Find the `ApiError` type (or equivalent) the app maps HTTP errors to.
