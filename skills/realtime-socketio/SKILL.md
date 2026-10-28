---
name: realtime-socketio
description: Use when adding or changing a socket.io event on either side of a web app (Angular client service and NgRx wiring, or the Express server emitting to tenant rooms).
applies_to: [angular-app, express-api]
---

# Skill: Realtime Socket.io

> One socket connection per tab, one service that owns it, events scoped to a tenant room, payloads that name the changed record so the client refetches or upserts. The REST API stays the source of truth.

## When this applies

- The client side: the socket.io client in the Angular app.
- The server side: the API pushes changes, for example an order placed by another user, a stock change, a register opened or closed, a new FX rate.
- Adding a new event to a cross-stack contract: events are part of the pinned contract like routes (see `api-contract`).

## Rules

### 1. Client: one injectable owns the connection; components never call `io()`

✅ Do
```ts
@Injectable({ providedIn: 'root' })
export class RealtimeService implements OnDestroy {
  private socket?: Socket;
  constructor(@Inject(APP_ENV) private env: AppEnvironment, private session: SessionService, private zone: NgZone) {}

  connect(): void {
    if (this.socket?.connected) return;
    this.socket = io(this.env.API_URL.replace(/\/api$/, ''), { auth: this.session.socketAuth() });
  }
  on<T>(event: string): Observable<T> {
    return new Observable<T>((sub) => {
      const handler = (data: T) => this.zone.run(() => sub.next(data));
      this.socket!.on(event, handler);
      return () => this.socket!.off(event, handler);
    });
  }
  ngOnDestroy(): void { this.socket?.disconnect(); }
}
```

❌ Don't
```ts
export class CheckoutComponent implements OnInit {
  ngOnInit() { const s = io(API); s.on('order-created', ...); } // new connection per visit, never closed
}
```

### 2. Client: socket events feed the store through one effect, never through components

✅ Do
```ts
inventoryChanged$ = createEffect(() => this.realtime.on<InventoryChangedEvent>('inventory:changed').pipe(
  map((e) => inventoryChangedRemotely({ itemIds: e.itemIds })),
));
```

❌ Don't
```ts
// three components subscribing to 'inventory:changed' and each refetching the list
```

### 3. Payloads carry ids and a version, not full money state; the client refetches or upserts

A socket payload is a hint. Balances, stock and the active register come from REST.

✅ Do
```ts
// server
io.to(tenantRoom(tenantId)).emit('register:closed', { registerId, closedAt, version });
// client effect
switchMap(({ registerId }) => this.api.getRegister(registerId).pipe(map((r) => registerLoaded({ register: r }))))
```

❌ Don't
```ts
io.emit('register:closed', { totals: { usd: 120.5, eur: 110.2 }, user }); // floats, broadcast to every tenant
```

### 4. Server: authenticate the handshake and join exactly one tenant room

Reuse the same auth and tenant resolution as REST (see `multi-tenancy`). Reject the connection when either fails.

✅ Do
```ts
io.use(async (socket, next) => {
  try {
    const ctx = await resolveSocketContext(socket.handshake); // same rules as the REST tenant middleware
    socket.data.tenantId = ctx.tenantId;
    socket.data.userId = ctx.userId;
    next();
  } catch {
    next(new Error('UNAUTHORIZED'));
  }
});
io.on('connection', (socket) => socket.join(tenantRoom(socket.data.tenantId)));
```

❌ Don't
```ts
io.on('connection', (socket) => socket.join(socket.handshake.query.tenant as string)); // client picks its tenant
```

### 5. Server: emit after the transaction commits, from the service layer

✅ Do
```ts
const order = await placeOrder(ctx, dto); // commits stock decrement, payment, receivable
realtime.toTenant(ctx.tenantId).emit('order:created', { orderId: order._id, version: order.__v });
```

❌ Don't
```ts
session.startTransaction();
io.to(room).emit('order:created', ...); // clients refetch before commit and see old stock
await session.commitTransaction();
```

### 6. Event names are namespaced `resource:verb` and listed in one constants file per side

✅ Do
```ts
export const RealtimeEvents = {
  orderCreated: 'order:created',
  inventoryChanged: 'inventory:changed',
  registerClosed: 'register:closed',
} as const;
```

❌ Don't
```ts
socket.on('newOrder', ...); socket.on('order_new', ...); // same event, two names, one never fires
```

Existing event names stay as they are; this convention is for new events.

### 7. Client: reconnect re-syncs state

Events missed while offline are gone. On `connect` after a disconnect, refetch what the screen shows.

✅ Do
```ts
this.realtime.on<void>('connect').pipe(skip(1)).subscribe(() => this.store.dispatch(realtimeReconnected()));
// effects on realtimeReconnected reload the active register and visible lists
```

❌ Don't
```ts
// assume no events were lost after a phone switched networks
```

### 8. Never put PII or money amounts in event payloads or socket logs

✅ Do
```ts
emit('receivable:updated', { receivableId, version });
```

❌ Don't
```ts
emit('receivable:updated', { customerName, nationalId, phone, balance }); // PII to every listener
```

## Anti-patterns

| Pattern | Why it hurts | Instead |
|---|---|---|
| `io.emit` to everyone | Cross-tenant data leak | `io.to(tenantRoom(id))` |
| Tenant taken from handshake query | Any client can join any tenant | Resolve server-side, same as REST |
| Emit inside an open transaction | Clients read stale data | Emit after commit |
| Socket as source of truth | Missed events leave wrong balances | Refetch via REST |
| Connection per component | Socket and memory leaks | One root service |
| Subscriptions without teardown | Duplicate handlers after navigation | `takeUntil(this.destroy$)` or an effect |

## Review checklist

- [ ] Client uses the single realtime service; no `io()` in components.
- [ ] Events reach the UI through an NgRx effect or one service.
- [ ] Server handshake authenticates and resolves the tenant server-side.
- [ ] Every emit targets a tenant room.
- [ ] Emits happen after commit, from the service layer.
- [ ] Payloads hold ids and versions only, no PII or amounts.
- [ ] New events are in the pinned contract and the constants file on both sides.
- [ ] Reconnect triggers a refetch.

## Adapt to your repo

- Client and server socket.io versions (they must be wire compatible).
- The socket URL and path, and whether it shares the API host.
- How the handshake authenticates (token in `auth`, cookie, query).
- How rooms are named today and whether they are per tenant.
- The current event list and payloads.
- Whether a Redis or other adapter runs for multiple API instances.
- Whether the client wraps the socket in a library (`ngx-socket-io` or plain `socket.io-client`).
