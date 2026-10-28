---
name: angular-forms
description: Use when building or changing a form in an Angular app (payments, order lines, stock entry, cash counts, customer data, expenses), especially anything with validation or money.
applies_to: [angular-app]
---

# Skill: Angular Forms

> Reactive Forms for anything with validation or money. Before Angular 14 forms are untyped, so declare an explicit interface; from 14 on, use typed forms for new ones. Server validation is always the real gate.

## When this applies

- New or changed forms: payment lines in a checkout cart, recording a partial payment on an invoice, adding or splitting an inventory batch, end-of-day cash counts per payment method and currency, customer data (tax ID, phone), fixed and variable expenses.
- Migrating a template-driven (`ngModel`) form. Many apps have both styles in use.

## Rules

### 1. New forms are Reactive Forms built with `FormBuilder`

`ngModel` stays only for a single search box or toggle with no validation.

✅ Do
```ts
this.form = this.fb.group({
  method: [null, Validators.required],
  currency: ['USD', Validators.required],
  amount: [null, [Validators.required, Validators.min(0.01)]],
  reference: [''],
});
```

❌ Don't
```html
<input [(ngModel)]="payment.amount" name="amount"> <!-- no validation state, money in a free field -->
```

### 2. Declare the value shape

Before Angular 14, `FormGroup` is untyped: write an interface for the form value and convert once at submit. On 14+, new forms use typed `FormGroup`/`FormControl` (see `angular-upgrade`); the convert-once-at-submit rule still applies.

✅ Do
```ts
interface PaymentFormValue { method: string; currency: 'USD' | 'EUR'; amount: string; reference: string; }

submit(): void {
  const v = this.form.getRawValue() as PaymentFormValue;
  this.store.dispatch(recordPayment({ invoiceId: this.invoiceId, dto: toPaymentDto(v) }));
}
```

❌ Don't
```ts
this.api.post('/invoices/payments', this.form.value); // any-typed, sends UI-only fields
```

### 3. Money inputs keep the typed text; conversion to minor units happens in one tested function

Users type `1.234,56` or `1234.56`. Never `parseFloat` and multiply in the component. See `money-and-currency`.

✅ Do
```ts
export function toPaymentDto(v: PaymentFormValue): PaymentDto {
  return { method: v.method, currency: v.currency, amountMinor: parseMoneyToMinor(v.amount, v.currency), reference: v.reference };
}
```

❌ Don't
```ts
amount: Number(this.form.value.amount) * 100 // 0.29 * 100 = 28.999999999999996
```

### 4. Cross-field rules go in a group validator

The payment lines of a mixed-currency order must cover the total per currency; a batch split cannot exceed the batch quantity.

✅ Do
```ts
export function splitWithinBatch(available: number): ValidatorFn {
  return (group: AbstractControl): ValidationErrors | null => {
    const qty = Number(group.get('quantity')?.value ?? 0);
    return qty > 0 && qty < available ? null : { splitOutOfRange: { available } };
  };
}
this.form = this.fb.group({ locationId: [null, Validators.required], quantity: [null] }, { validators: splitWithinBatch(batch.quantity) });
```

❌ Don't
```ts
onSubmit() { if (this.form.value.quantity > this.batch.quantity) alert('Error'); } // rule hidden in a handler
```

### 5. Async validators debounce and cancel

For uniqueness checks against endpoints such as `customers/check-field`.

✅ Do
```ts
export function uniqueTaxId(api: CustomersApi): AsyncValidatorFn {
  return (c) => timer(400).pipe(
    switchMap(() => api.checkField('taxId', c.value)),
    map((r) => (r.exists ? { taxIdTaken: true } : null)),
    catchError(() => of(null)),
  );
}
```

❌ Don't
```ts
(c) => api.checkField('taxId', c.value).pipe(map(...)) // one request per keystroke
```

### 6. Show errors after touch or submit, with one message map

✅ Do
```html
<div class="invalid-feedback" *ngIf="amount.invalid && (amount.touched || submitted)">
  {{ amount.errors | firstError }}
</div>
```

❌ Don't
```html
<span *ngIf="form.get('amount').errors?.required">Required</span>
<span *ngIf="form.get('amount').errors?.min">Too low</span> <!-- copied per field, per form -->
```

### 7. Disable submit while saving, and map server errors back to fields

The API validates again. A `422`/`400` with field details (shape in `api-contract`) is shown on the field.

✅ Do
```ts
this.saving = true;
this.api.addBatch(dto).pipe(finalize(() => (this.saving = false)), takeUntil(this.destroy$)).subscribe({
  error: (e: ApiError) => applyServerErrors(this.form, e.details),
});
```

❌ Don't
```ts
this.api.addBatch(dto).subscribe(); // double submit creates two batches
```

### 8. `FormArray` for repeated lines (payment lines, recipe ingredients, cash counts per method)

✅ Do
```ts
get counts(): FormArray { return this.form.get('counts') as FormArray; }
addCount(method: PaymentMethod): void {
  this.counts.push(this.fb.group({ methodId: [method.id], currency: [method.currency], counted: ['', Validators.required] }));
}
```

❌ Don't
```ts
countUsdCash = ''; countEurCard = ''; countUsdTransfer = ''; // one field per method, breaks when a method is added
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `ngModel` on money or stock fields | No validation state, easy double submit | Reactive form |
| `form.value` sent straight to the API | Leaks UI fields, untyped, mass-assignment risk on the API | Map to the contract DTO |
| `parseFloat` on amounts | Float drift, wrong decimal separator | One tested parse-to-minor function |
| Client-only validation | Anyone can call the API | Validate on both sides; API decides |
| Validation in submit handlers | Rules hidden and untested | Validators and group validators |
| Hardcoded sales tax or exchange rate in a form | Wrong when the rule or rate changes | Values from the API |

## Review checklist

- [ ] New forms are reactive and have a declared value shape (interface before 14, typed form on 14+).
- [ ] Money fields go through the shared parse function into minor units (or the repo's chosen representation).
- [ ] Submit is disabled while saving; server errors map back to fields.
- [ ] Async validators debounce and handle errors.
- [ ] Repeated lines use `FormArray`.
- [ ] The DTO sent matches the contract DTO by name.

## Adapt to your repo

- Check the Angular version: below 14 forms are untyped, 14+ has typed forms. Check for any form wrapper library.
- Find the shared error message mechanism (a pipe, a component, or none).
- Find how amounts are parsed today and which decimal separator the inputs accept.
- Find the server validation error shape the forms must map.
- List which forms still use `ngModel` for validated input.
