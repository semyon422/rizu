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
- `SeaClient.threaded = false` uses the `aqua/web` LuaSocket cosocket scheduler so websocket connect, read, and write waits can yield inside network-owned coroutines on the main thread.

## Invariants

- `SeaClient` may run the websocket in a thread, so thread initialization must be able to require `rizu.online.SphereWebsocket`.
- Main-thread websocket reads must run inside `SphereWebsocket`'s reader coroutine; `update()` should only pump the cosocket scheduler and must not call yielding socket reads directly.
- DNS lookup is still potentially blocking in main-thread mode until a separate resolver layer is added.
- Remote whitelist and validation stay owned by `sea.app.remotes`.
