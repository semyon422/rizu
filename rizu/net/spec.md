## Goal

The `rizu/net/` module owns game-client network policy that should be shared by online, UI, updater, package, and future main-thread HTTP/WebSocket callers.

## User Experience

- Network users should be able to write linear coroutine code such as `res, err = network:request(url)` without manually splitting DNS resolution from socket connection.
- The game should pump network readiness from one central update path instead of each feature owning an independent scheduler.
- TLS verification, operation timeouts, DNS behavior, and resolved-host connection rules should be consistent across client features.

## Architecture Decisions

- `NetworkService` owns the shared `CosocketScheduler`, async DNS resolution, DNS success cache, default socket timeout, websocket read timeout, and TLS verification policy.
- HTTP callers use `NetworkService:request(url, body, options)`, which resolves DNS, injects `scheduler`, `connect_host`, `timeout`, and default `ssl_params`, then delegates to `web.http.util.request`.
- Download callers can use `NetworkService:download(url, options)` for read-all downloads with `on_download` progress hooks, or `NetworkService:openStream(url, options)` for manual chunked upload/download through `web.HttpStream`.
- WebSocket callers use `NetworkService:createWebsocketConnection()` and `NetworkService:connectWebsocket(connection, url)` so DNS and transport policy stay centralized.
- WebSocket connections use the default socket timeout for connect and handshake, then use a separate 30 second reader timeout so the ping interval is not racing the connect timeout.
- DNS resolution still runs through `thread.async` because LuaSocket DNS lookup can block.
- Runtime diagnostics should stay centralized in `NetworkService`: callers can inspect counters and the latest network error without each feature inventing local logging/state.

## Invariants

- Callers should not parse URLs only to pass `connect_host`; that belongs in `NetworkService`.
- The URL host must remain the HTTP `Host` header and TLS SNI name even when TCP connects to a resolved IP address.
- `NetworkService:update()` is the central scheduler pump when the service is shared by multiple game systems.
- WebSocket reader timeout must stay longer than the online ping cadence unless the ping cadence changes at the same time.
- `openStream()` returns a connected stream. The caller owns request upload/download sequencing and must close the stream when it does not use `download()`.
- Feature-local network services are allowed as a fallback for isolated tests or legacy code, but normal game wiring should pass the shared service from `GameController`.

## Future Work and Open Questions

- Add a cancellation API for long-running HTTP streams/downloads so screens can stop work explicitly during unload or task replacement.
- Consider a shared progress/status shape for DNS, connect, TLS, upload, response wait, download, done, and failed states.
- Add a small end-to-end smoke test for the game-facing `NetworkService` HTTP/websocket wiring while keeping most edge cases on fake sockets.
- Keep DNS on `thread.async(socket.dns.toip)` unless the DNS thread becomes a real operational problem or a reliable async resolver library is adopted.
