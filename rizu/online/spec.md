## Goal

The `rizu/online/` module owns client-side online state, websocket connection management, and online client remotes.

## User Experience

- Online login state and leaderboards should stay synchronized with the server while the game is running.
- Connection loss should clear local user state and reconnect in the background without blocking the UI loop.

## Architecture Decisions

- `OnlineModel` owns online session/auth workflows backed by persisted online config.
- `AuthManager` performs login, logout, session restoration, and user refresh through `SeaClient`.
- `OnlineClient` stores client-observed online state such as the current user and leaderboard data.
- `MultiplayerModel` tracks client-side multiplayer state and coordinates room chart selection/download actions.
- `SeaClient` bridges websocket transport, ICC remotes, and validated server remotes.
- Client remote handlers live under `rizu.online.remotes`; server-side remote definitions remain in `sea`.
- `SeaClient` uses `web.ws.WebsocketConnection` with the `aqua/web` LuaSocket cosocket scheduler so websocket connect, read, and write waits can yield inside network-owned coroutines on the main thread.
- `SeaClient` requires an injected `rizu.net.NetworkService` for scheduler, DNS resolution, TLS policy, and resolved-host websocket connection behavior.
- ICC return messages decoded by the websocket reader are queued by `SeaClient` and dispatched during `SeaClient:update()`. This keeps RPC caller resumption outside the cosocket scheduler's active resume chain and prevents coroutine re-entry.
- `AuthManager` background entry points catch RPC failures, log the failure, and close the websocket so normal reconnect handling can recover without terminating the game.
- `SeaClient` owns online reconnect pacing; shared socket timeout and TLS verification policy come from `NetworkService`, and the reusable `aqua/web` layer only receives the selected transport options.

## Invariants

- Main-thread websocket reads must run inside `WebsocketConnection`'s reader coroutine; `update()` should only pump the cosocket scheduler and must not call yielding socket reads directly.
- Main-thread websocket writes must go through `WebsocketConnection:send` so one coroutine owns the websocket writer until its frame is fully sent.
- Websocket reader callbacks must not directly resume ICC RPC callers. `GameController:update()` drains `SeaClient` return messages after `NetworkService:update()` has unwound.
- `SeaClient` must assign `server_peer.ws` before starting `WebsocketConnection`'s reader coroutine, otherwise early server calls may try to reply through the disconnected peer.
- `SeaClient` must reset `server_peer.ws` to a disconnected peer before reconnect attempts, after send failures, and during unload so remote calls cannot target a stale websocket.
- Ping and heartbeat failures must close the current main-thread websocket and enter the normal reconnect path instead of escaping from the ping coroutine.
- Authentication and user-refresh timeouts must likewise remain contained by `AuthManager`'s background wrappers; they must not escape through `thread.coro` into the game loop.
- DNS lookup must not happen inside cosocket TCP connect on the main thread; use `NetworkService` to resolve first through the async resolver and keep the original URL host for HTTP `Host`, SNI, and future TLS hostname verification.
- Reconnect retries use exponential backoff from `reconnect_initial_interval` up to `reconnect_interval`, and successful connects reset the delay.
- After yielding operations such as DNS resolution, websocket connect, and initial user fetch, `SeaClient` must re-check `stopped` before running follow-up connection side effects.
- Remote whitelist and validation stay owned by `sea.app.remotes`.
- Server remote errors are intentionally allowed to surface loudly on the client instead of being hidden behind generic websocket recovery. Online protocol and server failures should fail early and visibly so they can be fixed while test coverage keeps these paths rare.
