---
name: angular-good-practices
description: Use when writing or reviewing any component, template, pipe or service in an Angular app; covers change detection, subscriptions, templates, typing and which modern APIs the repo's Angular version allows.
applies_to: [angular-app]
---

# Skill: Angular Good Practices

> OnPush, async pipe or `takeUntil(this.destroy$)`, `trackBy`, no logic in templates, explicit types. Modern APIs (signals, standalone, `@if/@for`, `inject()` fields, `takeUntilDestroyed`) are used only once the repo is on the Angular version that ships them; `angular-upgrade` has the table. Below that version, the rules here are the whole answer.

## When this applies

Every change under the Angular source. Screens such as a checkout cart, an inventory list (hundreds of items with batches per location), a cash register screen and receivables or payables lists may run on phones with little data, so change detection and payload size matter.

## Rules

### 1. Use `ChangeDetectionStrategy.OnPush` on every new component

Inputs are immutable; new data means a new reference.

✅ Do
```ts
@Component({
  selector: 'app-batch-row',
  templateUrl: './batch-row.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BatchRowComponent {
  @Input() batch!: InventoryBatch;
  @Output() split = new EventEmitter<string>();
}
```

❌ Don't
```ts
// mutating the input in place: OnPush parents never see the change
this.batch.quantity -= sold;
```

### 2. Prefer the async pipe; when you must subscribe, use `takeUntil(this.destroy$)`

On Angular 16+, `takeUntilDestroyed` replaces the destroy subject when you touch the file (see `angular-upgrade`). Below 16 it does not exist.

✅ Do
```ts
export class RegisterSummaryComponent implements OnInit, OnDestroy {
  summary$!: Observable<RegisterSummary>;
  private destroy$ = new Subject<void>();

  constructor(private store: Store, private toast: ToastService) {}

  ngOnInit(): void {
    this.summary$ = this.store.select(selectActiveRegisterSummary);
    this.store.select(selectCloseError).pipe(filter(Boolean), takeUntil(this.destroy$))
      .subscribe((err) => this.toast.error(err.message));
  }
  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

❌ Don't
```ts
ngOnInit() {
  this.socket.on('order-created').subscribe((o) => this.orders.push(o)); // never unsubscribed, leaks per visit
}
```

### 3. `trackBy` on every `*ngFor` over API data

On 17+ with built-in control flow, `@for` requires a `track` expression; use the id there too.

✅ Do
```html
<tr *ngFor="let item of items$ | async; trackBy: trackById">...</tr>
```
```ts
trackById(_: number, item: InventoryItem): string { return item.id; }
```

❌ Don't
```html
<tr *ngFor="let item of items">...</tr> <!-- every refresh re-renders 800 rows -->
```

### 4. No logic or function calls in templates; compute in the component, a selector or a pure pipe

✅ Do
```html
<span>{{ order.total | money: order.currency }}</span>
<span *ngIf="isOverdue">Overdue</span>
```

❌ Don't
```html
<span>{{ calcTotalWithTax(order) }}</span> <!-- runs every change detection cycle, and money math in the view -->
```

### 5. Money and rate math never happens in components

Totals, sales tax, currency conversion and rounding come from the API or one shared money utility. See `money-and-currency`.

✅ Do
```ts
this.total$ = this.store.select(selectCartTotals); // { usdMinor, eurMinor, rateSnapshot }
```

❌ Don't
```ts
this.totalEur = this.totalUsd * this.rate; // float math, unrounded, rate not snapshotted
```

### 6. Type everything; `any` needs a reason in review

Forms before Angular 14 are untyped and many HttpClient calls default loosely. Declare DTO interfaces and use them on every call.

✅ Do
```ts
getInvoice(id: string): Observable<InvoiceDto> {
  return this.http.get<InvoiceDto>(`${this.env.apiUrl}/invoices/${id}`);
}
```

❌ Don't
```ts
getInvoice(id): Observable<any> { return this.http.get(this.url + id); }
```

### 7. One injection style per codebase

Before Angular 14, `inject()` works only inside provider factories (`useFactory`, an `InjectionToken` factory), so constructor injection is the only option in components and services. Field-initializer `inject()` arrives in 14. Keep the codebase uniform: if the repo uses constructor DI, stay with it until a deliberate switch.

✅ Do
```ts
constructor(private http: HttpClient, private store: Store) {}
```

❌ Don't
```ts
private http = inject(HttpClient); // the 14+ field-initializer style, in a repo below 14 or one that uses constructor DI
```

### 8. Smart containers, presentational children

Containers talk to the store or services; children take `@Input`s and emit `@Output`s.

✅ Do
```html
<app-invoice-list [invoices]="invoices$ | async" (recordPayment)="onPayment($event)"></app-invoice-list>
```

❌ Don't
```ts
export class InvoiceListRowComponent {
  constructor(private http: HttpClient) {} // a table row calling the API per row
}
```

### 9. Avoid nested subscribes; compose with RxJS operators

✅ Do
```ts
this.route.paramMap.pipe(
  map((p) => p.get('id')!),
  switchMap((id) => this.invoices.get(id)),
  takeUntil(this.destroy$),
).subscribe((inv) => this.form.patchValue(inv));
```

❌ Don't
```ts
this.route.params.subscribe((p) => this.invoices.get(p.id).subscribe((inv) => ...));
```

### 10. Format dates and numbers through the registered locale, never by hand

Register the app's locale with `registerLocaleData` and use `DatePipe` or a money pipe. If a legacy date library such as moment is in the bundle, do not add new usage without a reason in the PR.

✅ Do
```html
{{ close.closedAt | date: 'dd/MM/yyyy HH:mm' }}
```

❌ Don't
```ts
const label = d.getDate() + '/' + (d.getMonth() + 1); // wrong timezone, no padding
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `Default` change detection on large lists | Inventory and order screens lag on phones | OnPush plus immutable updates |
| `subscribe` without teardown | Socket and store leaks, duplicated toasts | async pipe or `takeUntil(this.destroy$)` |
| Function calls in templates | Runs on every cycle | Precompute or pure pipe |
| Money math in components | Float drift, missing tax, different totals than the API | API values or the shared money utility |
| `any` on HTTP calls | Contract drift goes unnoticed | DTO interfaces from the contract |
| `setTimeout` to "fix" change detection | Hides a mutation bug | Emit a new reference |
| Heavy xlsx/PDF generation in the click handler | Freezes the UI | Lazy-load the export library, or generate on the API |

## Review checklist

- [ ] New components use OnPush.
- [ ] Every manual `subscribe` has `takeUntil(this.destroy$)` and `ngOnDestroy` completes the subject (or `takeUntilDestroyed` on 16+).
- [ ] Every `*ngFor` over data has `trackBy`.
- [ ] No function calls or money math in templates or components.
- [ ] HTTP calls are typed with the contract DTO.
- [ ] No signals, standalone components, `@if/@for`, `inject()` fields or `takeUntilDestroyed` below the Angular version that ships them.
- [ ] No new legacy date library usage without a stated reason.

## Adapt to your repo

- Check the Angular and RxJS versions; they decide which modern APIs are allowed.
- Check the lint setup (ESLint with angular-eslint, or TSLint) and the rules already enforced.
- Check `strict` and `strictTemplates` in `tsconfig.json`.
- Use the repo's component selector prefix (examples use `app-`).
- Find whether a shared money pipe or utility exists and its name.
- Count components on Default vs OnPush, to size an OnPush workstream.
