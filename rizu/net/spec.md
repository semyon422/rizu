## Goal

The `rizu/net/` module owns game-client network policy that should be shared by online, UI, updater, package, and future main-thread HTTP/WebSocket callers.

## User Experience

- Network users should be able to write linear coroutine code such as `res, err = network:request(url)` without manually splitting DNS resolution from socket connection.
- The game should pump network readiness from one central update path instead of each feature owning an independent scheduler.
- TLS verification, operation timeouts, DNS behavior, and resolved-host connection rules should be consistent across client features.

## Architecture Decisions

- `NetworkService` owns the shared `CosocketScheduler`, async DNS resolution, DNS success cache, default socket timeout, and TLS verification policy.
- HTTP callers use `NetworkService:request(url, body, options)`, which resolves DNS, injects `scheduler`, `connect_host`, `timeout`, and default `ssl_params`, then delegates to `web.http.util.request`.
- WebSocket callers use `NetworkService:createWebsocketConnection()` and `NetworkService:connectWebsocket(connection, url)` so DNS and transport policy stay centralized.
- DNS resolution still runs through `thread.async` because LuaSocket DNS lookup can block.

## Invariants

- Callers should not parse URLs only to pass `connect_host`; that belongs in `NetworkService`.
- The URL host must remain the HTTP `Host` header and TLS SNI name even when TCP connects to a resolved IP address.
- `NetworkService:update()` is the central scheduler pump when the service is shared by multiple game systems.
- Feature-local network services are allowed as a fallback for isolated tests or legacy code, but normal game wiring should pass the shared service from `GameController`.
