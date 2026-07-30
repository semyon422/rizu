# Web And Server Architecture (`sea`)

## Goal
The `sea/` tree contains the website, server-side logic, and shared online infrastructure. It should provide clear patterns for HTTP resources, websocket communication, shared memory coordination, and typed remote APIs.

## User Experience
- Web pages should render correctly through the custom Lua stack and cooperate with HTMX navigation rules.
- Online features should deliver messages reliably across workers and websocket connections.
- Server-side code should expose explicit, documented remote contracts instead of ad hoc cross-context calls.

## Web Development Conventions

- Routing is handled by resource classes registered in `sea/app/Resources.lua`.
- New HTTP endpoints should typically be added by creating a resource class and registering it in the resources list.
- Frontend templates use `etlua`.
- Wiki pages in `sea/wiki/` use markdown processed through `etlua`, so embedded Lua is allowed where established by the codebase.
- For links that must do a full navigation rather than HTMX interception, set `hx-boost="false"`.

## Resource Annotation Convention

- Web resources should use EmmyLua class annotations in the form:

```lua
---@class sea.MyResource: web.IResource
```

## Shared Memory And Repositories

- Use `web.SharedMemory` from `aqua/web/nginx/SharedMemory.lua` to access OpenResty shared dictionaries.
- Shared dictionaries must be declared in `nginx_config.lua` under `shared_dicts`.
- Wrap shared dictionary access in dedicated repo classes instead of scattering raw key usage.
- Initialize those repos from the shared-memory instance passed through the app setup.

## ICC And Remote Patterns

- ICC means inter-context communication between server and client, worker and worker, or thread and thread.
- Remote-facing APIs typically consist of:
  - a real implementation object such as `ServerRemote`,
  - a proxy `icc.Remote` on the caller side,
  - a validation wrapper for type safety and tooling,
  - a whitelist entry in `sea/app/remotes/whitelist.lua`.

## Architecture Decisions

### ADR: Single-host container deployment
- The baseline container deployment is one Docker Compose project containing OpenResty and NATS.
- Docker Compose mounts the local Git checkout into the official OpenResty image; it does not build an application image.
- OpenResty and NATS use host networking on Linux to preserve the existing loopback-only reverse-proxy and NATS contracts.
- NATS binds its client and monitoring ports to loopback and is not exposed publicly.
- Configuration, SQLite, and content-addressed chart and replay storage remain in their existing ignored checkout paths.
- Docker does not compile or download application dependencies. The checkout must contain compatible prebuilt `tree/` Lua modules and `bin/linux64/` native libraries, including the repository-pinned SQLite and Minacalc builds. Compose may pull the pinned OpenResty and NATS images when they are missing locally.
- The container exposes only Rizu's server-specific 7z, iconv, Minacalc, and SQLite libraries through `LD_LIBRARY_PATH`. OpenResty and Lua SSL modules use the container image's OpenSSL instead of the game runtime's bundled OpenSSL.

### ADR: NATS Broadcast Transport
- Cross-worker and cross-connection fan-out uses NATS pub/sub via `icc.BroadcastingPeer`.
- `UserConnections:broadcastAll()`, `:broadcastRoom(room_id)`, and `:broadcastUser(user_id)` return no-return remotes backed by `BroadcastingPeer`.
- Broadcasts are best-effort: `BroadcastingPeer:send()` returns `0` on publish failure (prints warning, doesn't crash the caller).
- NATS subjects follow the pattern `icc.broadcast.{scope}.{id}` where scope is `all`, `room`, or `user`.
- `sea.Peer:subscribe(subject)` and `:unsubscribe(subject)` manage NATS subscriptions with SID tracking. Idempotent, silently no-ops if NATS is unavailable.
- `Peer:setup_dispatch(client_task_handler)` installs the NATS→WebSocket dispatcher on the peer.
- `RestyNats` handles connection failure gracefully: returns `(nil, err)` instead of crashing. Caches initial connect failure to avoid retry storms. On receive loop death (socket error, parse error), resets state so subsequent calls reconnect automatically.

### ADR: Connection Tracking
- `UserConnectionsRepo` tracks connections using `c:{peer_id}` keys in shared memory with TTL.
- Online status is derived from active connections — no separate `u:` key. `isUserOnline()` checks `getPeerIdsByUserId()`.
- `getPeerIdsByUserId()` returns all peer IDs for a user (supports multi-socket users).
- `UserConnections:getOnlineUsers()` collects unique user IDs from connections and fetches in a single batch query via `UsersRepo:getUsersByIds(ids)`.
- `EMPTY_USER` is used for both anonymous and deleted users — both behave identically (`isAnon()` returns true).

### ADR: Context-Injection Remote Dispatch
- `icc.RemoteHandler` dispatches incoming paths against the real remote object and injects connection context into `self`.
- `IClientRemoteContext` and `IServerRemoteContext` exist for shared field annotations only and should not grow behavior methods.

### ADR: Subscription Lifecycle
- NATS subscriptions are managed by domain objects, not by `AuthServerRemote` or `MultiplayerServerRemote`.
- `Domain:onAuth()` subscribes to `icc.broadcast.user.{user_id}`.
- `Multiplayer:joinRoom()` subscribes to `icc.broadcast.room.{room_id}`; `leaveRoom()` unsubscribes.
- `WebsocketResource` subscribes to `icc.peer.{peer_id}` and `icc.broadcast.all` before `onConnect`.
- All subscription SIDs are cleaned up in `peer.broadcast_sids` on disconnect.

## Verification

- For remote-contract changes, verify:
  - remote wrapper and real implementation stay aligned,
  - whitelist entries are updated,
  - queue encoding and decoding still match,
  - tests cover message payloads where practical.
- For broadcast changes, verify:
  - `BroadcastingPeer` subjects match `Peer:subscribe()` subjects,
  - subscription/unsubscription pairs are balanced,
  - NATS failure doesn't crash the connection.
