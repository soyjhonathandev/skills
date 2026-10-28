---
name: angular-upgrade
description: Use when planning or executing an Angular major upgrade, or when someone proposes signals, standalone components, control flow, typed forms or takeUntilDestroyed and you need to know which Angular version allows them.
applies_to: [angular-app]
---

# Skill: Angular Upgrade

> Move one major at a time with `ng update`, keep every step shippable, and adopt modern APIs only after the upgrade that makes them stable has landed on trunk.

## When this applies

- Planning an upgrade workstream, especially from an Angular major that is out of support.
- Running `ng update` for any major.
- Reviewing a PR that uses signals, standalone components, `inject()` fields, `@if/@for`, `@defer`, typed forms or `takeUntilDestroyed`. If the repo is below the version that ships the API, the answer is no; this skill says when it becomes yes.

The target major is a team decision.

## What arrives when (adopt only after that step lands)

| Upgrade step | What becomes available | First use in your code |
|---|---|---|
| 13 to 14 | Typed reactive forms (`ng update` renames existing forms to `UntypedFormGroup`), `inject()` in field initializers, standalone in preview | Typed forms for new forms |
| 14 to 15 | Standalone APIs stable, functional guards and resolvers, `provideRouter`/`provideHttpClient` | New leaf components standalone |
| 15 to 16 | `takeUntilDestroyed` and `toSignal` (rxjs-interop, preview), signals preview, required inputs, View Engine libraries no longer load | Required inputs; audit old libraries first |
| 16 to 17 | Built-in control flow (`@if`, `@for`, `@switch`), `@defer`, signals stable, application builder (esbuild) | Control-flow migration, deferred heavy widgets (charts, xlsx export) |
| 17 and later | Signal inputs and queries, further signal APIs, zoneless work | Decide per step; read the release notes |

Check the Node, TypeScript and RxJS ranges for every step in the official update guide before starting. Do not copy ranges into this file.

## Rules

### 1. One major per branch, with `ng update`, migrations committed apart from manual fixes

✅ Do
```ts
// branch upgrade/angular-14 (prefix from the team's branch convention)
// commit 1: npx ng update @angular/core@14 @angular/cli@14   (schematic output only)
// commit 2: npx ng update @ngrx/store@14                        (schematic output only)
// commit 3: manual fixes so build, tests and e2e smoke pass
```

❌ Don't
```ts
// package.json edited by hand from 13 to 17, then "fix whatever breaks"
"@angular/core": "^17.0.0"
```

### 2. Move the ecosystem with Angular in the same step

NgRx majors follow Angular majors; ng-bootstrap, CDK, angular-eslint and the chart and socket wrappers publish compatibility tables. Check each before the step.

✅ Do
```ts
// upgrade notes in the PR body:
// @angular/* 14.x, @angular/cdk 14.x, @ngrx/* 14.x, @ng-bootstrap/ng-bootstrap <version from its table>
```

❌ Don't
```ts
// Angular 15 with NgRx 13 and ng-bootstrap built for 13: peer warnings ignored, runtime errors in modals
```

### 3. Each step must pass the same gate before the next starts

Build in production mode, unit tests, an e2e smoke scenario over the critical paths (for example: login, open a register session, an order in two currencies, a payment on an invoice, end-of-day close), bundle budgets.

✅ Do
```ts
// checklist in the step PR
// [x] prod build  [x] unit tests  [x] e2e smoke on the demo tenant  [x] budgets  [x] manual: checkout on a phone viewport
```

❌ Don't
```ts
// merge 14, start 15 the same day while 14 still has a failing register spec
```

### 4. Typed forms after 14: adopt per form, starting with new ones

`ng update` turns existing `FormGroup` into `UntypedFormGroup`. Convert a form only when you touch it.

✅ Do
```ts
// after the upgrade to 14 lands
const form = new FormGroup({
  currency: new FormControl<'USD' | 'EUR'>('USD', { nonNullable: true }),
  amount: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
});
```

❌ Don't
```ts
// in a repo below 14
new FormControl<string>(''); // does not compile before 14
```

### 5. Standalone after 15: leaf components first, feature by feature

NgModules and standalone components coexist. Use the `@angular/core:standalone` schematic per feature, not across the app in one PR.

✅ Do
```ts
// after the upgrade to 15 lands
@Component({ standalone: true, selector: 'app-currency-badge', imports: [NgIf], template: '...' })
export class CurrencyBadgeComponent {}
```

❌ Don't
```ts
// in a repo below 15, or a single PR converting every lazy module at once
@Component({ standalone: true, ... })
```

### 6. `takeUntilDestroyed` after 16 replaces the destroy subject only when the file is touched

✅ Do
```ts
// after the upgrade to 16 lands
constructor(private store: Store) {
  this.store.select(selectCloseError).pipe(takeUntilDestroyed()).subscribe((e) => this.show(e));
}
```

❌ Don't
```ts
// below 16: takeUntilDestroyed does not exist; keep takeUntil(this.destroy$)
```

### 7. Signals after 17 for component-local state; NgRx stays the shared store

✅ Do
```ts
// after the upgrade to 17 lands
readonly selectedLocation = signal<string | null>(null);
readonly batches = toSignal(this.store.select(selectAllBatches), { initialValue: [] });
readonly visible = computed(() => this.batches().filter((b) => b.locationId === this.selectedLocation()));
```

❌ Don't
```ts
// replacing NgRx inventory state with a signal service in the same PR as the upgrade
```

### 8. Control flow after 17 through the schematic, as its own PR

✅ Do
```html
<!-- after the upgrade to 17 lands, via ng generate @angular/core:control-flow -->
@for (item of items(); track item.id) { <app-batch-row [batch]="item" /> }
```

❌ Don't
```html
<!-- hand-converting templates inside a feature PR; mixing @for and *ngFor in one template -->
```

### 9. The upgrade owns `package.json`, the lockfile, `angular.json` and `tsconfig*`

No feature work edits those files while an upgrade step is open (shared-file rule in parallel work).

✅ Do
```ts
// work plan: shared files owner = the upgrade; feature work requests dependency changes through it
```

❌ Don't
```ts
// a feature PR adding a dependency while the upgrade branch rewrites the lockfile
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Skipping majors | Schematics only migrate one step | One major at a time, in order |
| Modern APIs before the step lands | Does not compile, or mixes paradigms | Wait for the step, then adopt per file |
| Upgrade plus refactor in one PR | Unreviewable, hard to revert | Schematic commits, then fixes, then refactors later |
| Ignoring peer warnings | Runtime failures in modals, charts, sockets | Compatibility tables per library |
| No phone-viewport check | Mobile regressions found by customers | Manual phone pass in the gate |

## Review checklist

- [ ] The PR moves exactly one Angular major.
- [ ] Schematic output and manual fixes are separate commits.
- [ ] NgRx, CDK, ng-bootstrap and lint tooling are on compatible versions.
- [ ] The step gate passed (build, tests, e2e smoke, budgets, phone pass).
- [ ] No API is used before the step that makes it available.
- [ ] Only the upgrade touched `package.json`, the lockfile and `angular.json`.

## Adapt to your repo

- Record the exact versions of `@angular/*`, `@ngrx/*`, `@ng-bootstrap/ng-bootstrap`, Bootstrap, RxJS and TypeScript.
- Find the Node version (`.nvmrc` or `engines`).
- List libraries that may block the path: chart wrapper, socket.io client wrapper, PDF and xlsx libraries, animation wrappers, any View Engine-only library.
- Check the builder in `angular.json` and the bundle budgets.
- If the repo has more than one Angular app, decide whether they upgrade together or on separate schedules.
- Agree on the target major.
