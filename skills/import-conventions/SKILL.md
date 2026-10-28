---
name: import-conventions
description: Use when adding imports, path aliases, barrels or a new shared folder in an Angular app; covers import order, aliases, lazy boundaries and library imports.
applies_to: [angular-app]
---

# Skill: Import Conventions

> Imports say where code lives and must not defeat lazy loading. Use the repo's path aliases, keep one import order, never import across feature modules, and import heavy libraries only where and when they are needed.

## When this applies

- Any new or moved import in an Angular app.
- Adding a tsconfig `paths` alias or an `index.ts` barrel.
- Importing a heavy library (xlsx, a PDF generator, chart.js, moment, lottie) in a feature.

## Rules

### 1. Use the repo's path aliases for core, shared and environments; relative paths only within a feature

Use the alias names the repo defines. Examples use `@core/*`, `@shared/*`, `@env/*` as placeholders.

✅ Do
```ts
import { SessionService } from '@core/session/session.service';
import { MoneyPipe } from '@shared/pipes/money.pipe';
import { BatchRowComponent } from './batch-row/batch-row.component';
```

❌ Don't
```ts
import { SessionService } from '../../../../core/session/session.service';
```

If the repo has no aliases, do not add them inside a feature PR; propose them as their own change (tsconfig is a shared file).

### 2. Never import from another feature module's folder

Feature modules are lazy chunks. A cross-feature import pulls the other chunk into yours or creates a cycle.

✅ Do
```ts
// orders needs the stock of a product: use the shared API service or a selector from a shared slice
import { InventoryApiService } from '@core/api/inventory-api.service';
```

❌ Don't
```ts
// orders/order-cart.component.ts
import { InventoryListComponent } from '../../inventory/inventory-list/inventory-list.component';
```

### 3. Keep one import order, separated by blank lines

Angular and RxJS, then third-party, then aliases (core, shared, env), then relative. If a lint rule enforces order, the lint rule wins.

✅ Do
```ts
import { ChangeDetectionStrategy, Component, Input } from '@angular/core';
import { Store } from '@ngrx/store';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

import { NgbModal } from '@ng-bootstrap/ng-bootstrap';

import { MoneyPipe } from '@shared/pipes/money.pipe';

import { selectOpenInvoice } from '../state/invoice.selectors';
```

❌ Don't
```ts
import { selectOpenInvoice } from '../state/invoice.selectors';
import { Component } from '@angular/core';
import * as rx from 'rxjs';
import { MoneyPipe } from '@shared/pipes/money.pipe';
```

### 4. Import RxJS operators by name; never import the whole library

✅ Do
```ts
import { filter, switchMap, takeUntil } from 'rxjs/operators';
```

❌ Don't
```ts
import * as rxjs from 'rxjs';
import 'rxjs/add/operator/map'; // RxJS 5 patch style
```

### 5. Heavy libraries load on demand

xlsx and the PDF generator are used only when the user exports a report. Load them with a dynamic import inside the handler so they stay out of the initial and feature chunks.

✅ Do
```ts
async exportInventory(rows: InventoryExportRow[]): Promise<void> {
  const XLSX = await import('xlsx');
  const sheet = XLSX.utils.json_to_sheet(rows);
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, sheet, 'Inventory');
  XLSX.writeFile(book, 'inventory.xlsx');
}
```

❌ Don't
```ts
import * as XLSX from 'xlsx'; // at the top of a component the orders module also imports
```

If the API already generates a report as a download, prefer that endpoint over client generation for large data.

### 6. Barrels only at a folder's public boundary, never re-exporting a whole feature

✅ Do
```ts
// shared/pipes/index.ts
export { MoneyPipe } from './money.pipe';
export { FirstErrorPipe } from './first-error.pipe';
```

❌ Don't
```ts
// inventory/index.ts
export * from './inventory.module';
export * from './state'; // pulls the lazy module into whoever imports the barrel
```

### 7. Import types from the contract DTO file, not from a component that happens to declare them

✅ Do
```ts
import { PendingAccountDto } from '@core/api/dto/pending-account.dto';
```

❌ Don't
```ts
import { PendingAccount } from '../../accounts/account-detail/account-detail.component';
```

### 8. The environment is injected, not imported, outside the root module

✅ Do
```ts
constructor(@Inject(APP_ENV) private env: AppEnvironment) {}
```

❌ Don't
```ts
import { environment } from '../../../environments/environment';
```

### 9. No new date or utility library without a reason in the PR

If moment is already in the bundle, adding date-fns or lodash next to it doubles the code for the same job.

✅ Do
```ts
import { formatDate } from '@angular/common';
const label = formatDate(invoice.closedAt, 'dd/MM/yyyy', 'en');
```

❌ Don't
```ts
import { format } from 'date-fns'; // a second date library for one label
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Deep relative paths (`../../../../`) | Break on every move, hide the layer | Path aliases |
| Cross-feature imports | Defeats lazy loading, creates cycles | Core service or shared slice |
| Static import of xlsx or PDF libraries | Bigger chunks on phones with little data | Dynamic import in the handler |
| `export *` feature barrels | Pulls lazy modules into eager code | Narrow barrels for shared folders |
| Types imported from components | Couples layers, drifts from the contract | DTO files |
| A second library for an existing job | Bundle bloat | Use what the repo already has |

## Review checklist

- [ ] Aliases used for core, shared and environment; relative only within a feature.
- [ ] No import crosses into another feature folder.
- [ ] Import order matches the repo rule or lint.
- [ ] xlsx, PDF and chart code is loaded on demand where it is not needed at first paint.
- [ ] No `export *` barrel for a feature.
- [ ] DTO types come from the contract DTO files.
- [ ] No new third-party library without a stated reason (and the dependency change is made by the track that owns `package.json`).

## Adapt to your repo

- The tsconfig `paths` aliases, if any.
- Whether a lint rule enforces import order or module boundaries.
- Where DTO interfaces live today.
- How xlsx and the PDF library are imported today and which chunks contain them.
- The RxJS version (6 vs 7 changes operator import paths).
