---
name: angular-architecture
description: Use when adding or moving a feature, route, module, guard or environment key in an Angular app built on NgModules (lazy feature modules, CoreModule, SharedModule).
applies_to: [angular-app]
---

# Skill: Angular Architecture

> NgModule feature modules, lazy routes, one CoreModule, one SharedModule, environments read through one token. These rules hold on any Angular version that still uses NgModules. Standalone structure (Angular 15+) and when to move to it live in `angular-upgrade`.

## When this applies

- Adding a screen (a new route under `inventory`, `orders`, `customers`, `settings`, ...) or a new lazy module.
- Adding a singleton service, interceptor, guard or resolver.
- Reading or adding a key in the environment object.
- Moving code between feature modules, or deciding whether something is "shared".
- Planning parallel work (several branches or agents at once): routing modules and `app.module.ts` are shared files owned by one stream of work.

## Rules

### 1. One lazy feature module per top-level route

Each top-level route loads its module with `loadChildren` and a dynamic import. Feature modules never import each other.

✅ Do
```ts
// app-routing.module.ts
const routes: Routes = [
  {
    path: 'inventory',
    canLoad: [AuthGuard],
    loadChildren: () => import('./inventory/inventory.module').then((m) => m.InventoryModule),
  },
  { path: 'orders', canLoad: [AuthGuard], loadChildren: () => import('./orders/orders.module').then((m) => m.OrdersModule) },
];
```

❌ Don't
```ts
// app.module.ts: eager import puts the whole inventory screen in main.js
@NgModule({ imports: [BrowserModule, InventoryModule, OrdersModule, AppRoutingModule] })
export class AppModule {}
```

### 2. Keep child routes inside the feature's own routing module

Child paths (`items`, `receipts`, `shipments`, `transfer-history`) live in `<feature>-routing.module.ts` with `RouterModule.forChild`. Only the root uses `forRoot`.

✅ Do
```ts
const routes: Routes = [
  { path: '', component: InventoryShellComponent, children: [
    { path: 'items', component: InventoryListComponent },
    { path: 'receipts', component: StockReceiptsComponent },
    { path: 'transfer-history', component: TransferHistoryComponent },
  ] },
];
@NgModule({ imports: [RouterModule.forChild(routes)], exports: [RouterModule] })
export class InventoryRoutingModule {}
```

❌ Don't
```ts
// app-routing.module.ts growing a flat list of every screen in the product
{ path: 'inventory/receipts', component: StockReceiptsComponent },
{ path: 'inventory/shipments', component: StockShipmentsComponent },
```

### 3. Singletons go in CoreModule, imported once

Interceptors, the auth and tenant services, the realtime connection service and app-wide guards are provided once. Guard CoreModule against a second import.

✅ Do
```ts
@NgModule({
  providers: [
    { provide: HTTP_INTERCEPTORS, useClass: ApiInterceptor, multi: true },
  ],
})
export class CoreModule {
  constructor(@Optional() @SkipSelf() parent: CoreModule) {
    if (parent) throw new Error('CoreModule is imported only by AppModule');
  }
}
```

❌ Don't
```ts
// inventory.module.ts: a second interceptor instance, requests get the header twice
providers: [{ provide: HTTP_INTERCEPTORS, useClass: ApiInterceptor, multi: true }]
```

### 4. SharedModule holds declarables only, no providers

Pipes (`MoneyPipe`), presentational components (currency badge, empty state) and re-exported common modules. A provider in SharedModule creates one instance per lazy module.

✅ Do
```ts
@NgModule({
  declarations: [MoneyPipe, CurrencyBadgeComponent, EmptyStateComponent],
  imports: [CommonModule, NgbModule],
  exports: [CommonModule, NgbModule, MoneyPipe, CurrencyBadgeComponent, EmptyStateComponent],
})
export class SharedModule {}
```

❌ Don't
```ts
@NgModule({ providers: [CartService] }) // each lazy module gets its own cart state
export class SharedModule {}
```

### 5. Services that hold state use `providedIn: 'root'`; feature-only helpers are provided in the feature

✅ Do
```ts
@Injectable({ providedIn: 'root' })
export class ExchangeRateService {
  constructor(private http: HttpClient, @Inject(APP_ENV) private env: AppEnvironment) {}
  latest(): Observable<ExchangeRateDto> {
    return this.http.get<ExchangeRateDto>(`${this.env.apiUrl}/exchange-rates/latest`);
  }
}
```

❌ Don't
```ts
@Component({ selector: 'app-order-cart', providers: [ExchangeRateService] }) // a new copy per cart
```

### 6. Read the environment through one injection token

The environment object carries values such as `production`, `apiUrl` and login or sign-up URLs. Inject it; never import `environments/environment` deep in a feature. Client keys (an analytics project key, a payment provider's publishable key, a support widget id) are referred to by name, never pasted into code or docs.

✅ Do
```ts
export const APP_ENV = new InjectionToken<AppEnvironment>('APP_ENV');
// app.module.ts
providers: [{ provide: APP_ENV, useValue: environment }]
```

❌ Don't
```ts
import { environment } from '../../../environments/environment';
const url = 'https://api.example/api/orders'; // hardcoded host, breaks staging and tests
```

### 7. Guards decide navigation, the API decides access

`CanLoad`/`CanActivate` hide screens a role cannot use, for example a cashier opening the profit and loss reports. The API still enforces the permission.

✅ Do
```ts
@Injectable({ providedIn: 'root' })
export class ModuleAccessGuard implements CanActivate {
  constructor(private session: SessionService, private router: Router) {}
  canActivate(route: ActivatedRouteSnapshot): boolean | UrlTree {
    return this.session.canAccess(route.data.module) || this.router.parseUrl('/error/403');
  }
}
```

❌ Don't
```ts
// component hides the button and assumes that is security
<button *ngIf="user.role !== 'cashier'" (click)="deleteBatch()">Delete batch</button>
```

### 8. Resolve once per route, not in every child

Data the whole feature needs (the active register session, the current tenant, today's exchange rate) loads once at the shell level, through a resolver or an NgRx effect triggered on route enter.

✅ Do
```ts
{ path: '', component: CheckoutShellComponent, resolve: { session: ActiveSessionResolver }, children: checkoutChildren }
```

❌ Don't
```ts
// every checkout child component calls GET /register-sessions/active in ngOnInit
```

### 9. Error routes and tenant routes stay top level

`error/400..504`, `tenant-not-found`, `login-callback` and `auth` must load without a tenant session. Do not put them behind the auth guard.

✅ Do
```ts
{ path: 'login-callback', component: LoginCallbackComponent },
{ path: 'tenant-not-found', component: TenantNotFoundComponent },
{ path: 'error', loadChildren: () => import('./error/error.module').then((m) => m.ErrorModule) },
{ path: '', canActivate: [AuthGuard], children: tenantRoutes },
```

❌ Don't
```ts
{ path: '', canActivate: [AuthGuard], children: [...tenantRoutes, { path: 'error', ... }] } // redirect loop on 401
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| Feature module importing another feature module | Breaks lazy loading, circular chunks | Move the shared piece to SharedModule or a `providedIn: 'root'` service |
| Providers in SharedModule | One instance per lazy module, state diverges | `providedIn: 'root'` or CoreModule |
| Hardcoded API host | Breaks per-environment builds and e2e ports | `APP_ENV.apiUrl` |
| Guards as the only permission check | Anyone can call the API directly | API authz, guard for UX only |
| Two parallel streams editing `app-routing.module.ts` | Merge conflicts, lost routes | One owner; others request changes |
| A 3000-line module with every screen | Slow first load on phones with little data | Split by route group |

## Review checklist

- [ ] New screens are under an existing lazy module or a new `loadChildren` entry.
- [ ] No feature module imports another feature module.
- [ ] No providers added to SharedModule.
- [ ] Environment values come from the injected token, no hardcoded hosts or keys.
- [ ] Guards are paired with an API-side permission check.
- [ ] Routing module and `app.module.ts` edits belong to the stream of work that owns them.
- [ ] New route paths follow the existing naming of that section.

## Adapt to your repo

- Check the Angular version in `package.json`. On 15+ new code may be standalone; see `angular-upgrade` before mixing styles.
- Check the real folder layout (`src/app/<feature>`, `pages/`, `modules/`).
- Check whether CoreModule and SharedModule exist, or what plays their role.
- Check whether the environment is imported directly today or already goes through a token.
- Find the guard names and how a role's permissions reach the client.
- Find the route naming rule per section (language, casing) so new child routes match.
- If the repo has more than one Angular app, check whether they share a library or are fully separate.
