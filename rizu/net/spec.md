## Goal

The `rizu/net/` module owns game-client network policy that should be shared by online, UI, updater, package, and future main-thread HTTP/WebSocket callers.

## User Experience

- Network users should be able to write linear coroutine code such as `res, err = network:request(url)` without manually splitting DNS resolution from socket connection.
- The game should pump network readiness from one central update path instead of each feature owning an independent scheduler.
- TLS verification, operation timeouts, DNS behavior, and resolved-host connection rules should be consistent across client features.

## Architecture Decisions

- `NetworkService` owns the shared `CosocketScheduler`, async DNS resolution, DNS success cache, default socket timeout, websocket read timeout, and TLS verification policy.
- HTTP callers use `NetworkService:request(url, body, options)`, which resolves DNS, injects `scheduler`, `connect_host`, `timeout`, and default `ssl_params`, then delegates to `web.http.util.request`.
- Download callers can use `NetworkService:download(url, options)` for read-all downloads with `on_status` progress events or `on_download` chunk progress, or `NetworkService:openStream(url, options)` for manual chunked upload/download through `web.HttpStream`.
- WebSocket callers use `NetworkService:createWebsocketConnection()` and `NetworkService:connectWebsocket(connection, url)` so DNS and transport policy stay centralized.
- WebSocket connections use the default socket timeout for connect and handshake, then use a separate 30 second reader timeout so the ping interval is not racing the connect timeout.
- DNS resolution still runs through `thread.async` because LuaSocket DNS lookup can block.
- Runtime diagnostics should stay centralized in `NetworkService`: callers can inspect counters and the latest network error without each feature inventing local logging/state.
- `NetworkService:cancelStreams(err)` cancels active HTTP streams/downloads owned by the shared service, allowing screens and unload paths to stop long-running transfers explicitly.
- Network operations may report a shared `on_status(status)` shape with states such as `dns`, `connecting`, `uploading`, `waiting_response`, `downloading`, `done`, `failed`, and `canceled`.
- `mcp.Server` hosts the running game's MCP Streamable HTTP endpoint on the shared scheduler. The reusable protocol implementation lives in `aqua/mcp`; `GameController` injects the game identity, configuration, and tools.
- The server is primarily a development interface for agents working on the game. It gives them runtime observation, reproduction, control, and verification capabilities that repository access alone cannot provide.
- The MCP surface exposes focused runtime-state, screenshot, and restart tools alongside the trusted `lua_eval` tool. A development agent can inspect the current screen, chart selection, preview state, capture the rendered frame, request a LÖVE-managed restart, or manipulate the `GameController` on the LÖVE main thread.
- `lua_eval` remains a developer escape hatch. Focused tools use schema-validated inputs and outputs plus explicit read-only, destructive, idempotent, and open-world annotations.

## Invariants

- Callers should not parse URLs only to pass `connect_host`; that belongs in `NetworkService`.
- The URL host must remain the HTTP `Host` header and TLS SNI name even when TCP connects to a resolved IP address.
- `NetworkService:update()` is the central scheduler pump when the service is shared by multiple game systems.
- WebSocket reader timeout must stay longer than the online ping cadence unless the ping cadence changes at the same time.
- `openStream()` returns a connected stream. The caller owns request upload/download sequencing and must close the stream when it does not use `download()`.
- Active streams must unregister themselves when closed so later cancellation does not touch completed transfers.
- `on_upload` / `on_download` remain supported as focused chunk-level hooks; `NetworkService` mirrors them into `on_status` when both are present.
- Feature-local network services are allowed as a fallback for isolated tests or legacy code, but normal game wiring should pass the shared service from `GameController`.
- The MCP listener binds to `127.0.0.1` by default, rejects every request carrying an `Origin` header, and supports an optional bearer token from ignored `userdata/mcp.lua`. A non-loopback listener does not start without a non-empty token and defaults to 120 endpoint requests per minute per client IP.
- MCP requests execute on the game main thread. Tool implementations must not block for long periods, and arbitrary Lua evaluation remains a trusted developer capability rather than a sandbox.
- `restart_game` queues `love.event.quit("restart")`; the current response is written before the main loop consumes the quit event. The custom loop preserves the `"restart"` quit code through asynchronous thread shutdown so LÖVE relaunches the process, after which clients must reconnect.
- The game enables MCP sessions over request/response JSON on `POST /mcp`. Sessions scope request IDs and cooperative cancellation; `DELETE /mcp` terminates a session. `GET` returns 405 because server-initiated SSE messages are not yet supported.

## Future Work and Open Questions

- Expose `NetworkService` diagnostics and recent status events in a dev/debug UI, possibly with a polished in-game view later.
- Keep DNS on `thread.async(socket.dns.toip)` unless the DNS thread becomes a real operational problem or a reliable async resolver library is adopted.
- Add an in-game MCP status surface showing listener state, remote exposure, active clients, and recent tool calls; add approval controls before exposing narrower player-facing mutation tools.
- Add further focused read-only and state-changing tools only for workflows proven useful during development.
- Add SSE only when server-initiated notifications or requests have a concrete consumer.
- Integrate the reusable `mcp.Client` with the in-game AI agent only after a concrete workflow establishes the required lifecycle and cancellation behavior.
