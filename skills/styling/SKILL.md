---
name: styling
description: Use when writing or reviewing styles, layout or UI widgets in an Angular app that uses Bootstrap SCSS and ng-bootstrap (component styles, theme variables, global SCSS).
applies_to: [angular-app]
---

# Skill: Styling

> Bootstrap utilities and ng-bootstrap widgets first, component SCSS second, theme variables for anything brand-wide, global styles last. Mobile first when the app is used on phones.

## When this applies

- Any template or SCSS change.
- Adding a modal, dropdown, datepicker, tooltip or toast.
- Styling money, currency badges, stock alerts or the surplus/shortage result of an end-of-day cash close.

Decision order for a new style, first match wins:

1. A Bootstrap utility class (`d-flex`, `gap-2`, `text-end`, `fw-semibold`).
2. An ng-bootstrap component for behaviour (modal, dropdown, datepicker, typeahead, toast).
3. Component SCSS (encapsulated by default).
4. A theme variable or mixin in the shared SCSS when the value is brand-wide.
5. Global styles, only for resets and third-party overrides, with a comment saying why.

## Rules

### 1. Use Bootstrap utilities before writing SCSS

✅ Do
```html
<div class="d-flex justify-content-between align-items-center gap-2 mb-3">
  <h2 class="h5 mb-0">Close register</h2>
  <button class="btn btn-primary btn-sm">Close</button>
</div>
```

❌ Don't
```scss
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
```

### 2. Use ng-bootstrap for interactive widgets; do not hand-roll them or add a second UI kit

✅ Do
```ts
constructor(private modal: NgbModal) {}
confirmReverse(): void {
  const ref = this.modal.open(ConfirmReverseOrderComponent, { centered: true, backdrop: 'static' });
  ref.componentInstance.orderId = this.orderId;
}
```

❌ Don't
```ts
document.querySelector('.my-modal')!.classList.add('show'); // no focus trap, no Escape, no a11y
```

### 3. Colors, spacing and radii come from theme variables, never literal values

✅ Do
```scss
@use 'theme' as t; // the repo's shared SCSS entry
.stock-low { color: t.$danger; padding: t.$spacer * 0.5; }
```

❌ Don't
```scss
.stock-low { color: #e3342f; padding: 7px; }
```

### 4. Component styles stay encapsulated; `::ng-deep` only under `:host`, with a reason

✅ Do
```scss
// ng-bootstrap datepicker inside the report filter needs a compact day cell
:host ::ng-deep .ngb-dp-day { width: 2rem; }
```

❌ Don't
```scss
::ng-deep .ngb-dp-day { width: 2rem; } // leaks into every datepicker in the app
```

### 5. Mobile first: base styles for the phone, breakpoints add up

Checkout, register and inventory screens are often used on phones. Test at 360 px wide.

✅ Do
```html
<div class="row g-2">
  <div class="col-12 col-md-6 col-xl-4" *ngFor="let p of products; trackBy: trackById">...</div>
</div>
```

❌ Don't
```scss
.product-grid { width: 1200px; } // horizontal scroll on every phone
```

### 6. Money is right-aligned, tabular, and always shows its currency

With two currencies on the same screen, never show a bare number.

✅ Do
```html
<td class="text-end font-monospace">{{ line.amountMinor | money: line.currency }}</td>
```

❌ Don't
```html
<td>{{ line.amount }}</td> <!-- is that dollars or euros? -->
```

### 7. State is color plus text or icon, never color alone

Surplus/shortage, overdue invoice, low stock.

✅ Do
```html
<span class="badge bg-danger"><i class="bi bi-exclamation-triangle" aria-hidden="true"></i> Shortage</span>
```

❌ Don't
```html
<span class="text-danger">{{ diff }}</span> <!-- color-blind users see a plain number -->
```

### 8. Global SCSS is for resets, Bootstrap configuration and third-party overrides only

✅ Do
```scss
// styles.scss: Bootstrap variables before the import, then the import, then overrides
$primary: $brand-primary; // use the repo's brand variable
@import 'bootstrap/scss/bootstrap';
```

❌ Don't
```scss
// styles.scss
.inventory-table td:nth-child(3) { font-weight: bold; } // feature style in the global file
```

### 9. Do not change Bootstrap variables or global SCSS from feature work

They are shared files: one owner at a time when work runs in parallel.

✅ Do
```ts
// work plan: styles.scss and the theme partial have one owner; other work requests tokens
```

❌ Don't
```ts
// two parallel branches each adding a $primary override
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Hex values in component SCSS | Theme changes miss them | Theme variables |
| Unscoped `::ng-deep` | Global leak, hard to trace | `:host ::ng-deep` with a reason, or global override section |
| Hand-rolled modals and dropdowns | No focus management or keyboard support | ng-bootstrap |
| A second UI kit for one widget | Bundle size, two design languages | ng-bootstrap or CDK |
| Desktop-only layouts | Unusable on phones | Mobile-first grid |
| Inline `style=""` for layout | Not reusable, beats utilities in specificity | Utility classes |
| Bare amounts | Currencies confused | Money pipe with currency |

## Review checklist

- [ ] Utilities used before custom SCSS.
- [ ] Widgets come from ng-bootstrap.
- [ ] No literal colors or magic spacing in component SCSS.
- [ ] Any `::ng-deep` is under `:host` and has a reason.
- [ ] Layout checked at 360 px.
- [ ] Money shows its currency and is right-aligned.
- [ ] Global SCSS and theme files were edited only by their owner.

## Adapt to your repo

- Check the Bootstrap major. The examples use Bootstrap 5 names; Bootstrap 4 differs (for example `ms-2` vs `ml-2`, `text-end` vs `text-right`).
- Find the shared SCSS entry, theme partial names and brand variables.
- Find the icon set (the examples assume Bootstrap Icons).
- Check `inlineStyleLanguage` and `stylePreprocessorOptions` in `angular.json`.
- Find whether a money pipe exists and its name (examples use `money`).
- Find what the CDK overlay powers, if it is in use.
