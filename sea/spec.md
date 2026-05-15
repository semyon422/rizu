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

### ADR: Shared-Memory Queue Transport Across Workers
- Cross-worker or cross-connection communication should use shared-memory queues such as `aqua/icc/SharedMemoryQueue.lua`.
- Queue messages must be stored as encoded strings, typically through `icc.StringBufferPeer`, because OpenResty shared dictionaries only support strings or numbers in list-like storage.

### ADR: Context-Injection Remote Dispatch
- `icc.RemoteHandler` dispatches incoming paths against the real remote object and injects connection context into `self`.
- `IClientRemoteContext` and `IServerRemoteContext` exist for shared field annotations only and should not grow behavior methods.

### ADR: Async Delivery For Websocket Feeds
- Use `ngx.thread.spawn` inside websocket resources for background loops that pop from shared-memory queues and deliver messages to clients.

## Verification

- For remote-contract changes, verify:
  - remote wrapper and real implementation stay aligned,
  - whitelist entries are updated,
  - queue encoding and decoding still match,
  - tests cover message payloads where practical.
