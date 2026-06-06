# Bancho Module

## Goal

Provide an osu!-compatible Bancho server implementation in Lua under `bancho/`, integrated into this repository's stack and conventions rather than copying bancho.py architecture verbatim.

## User Experience

The server should be usable by real osu! clients for the core flows we care about now:

- login and session handling
- chat and private messages
- presence and stats updates
- spectating basics
- multiplayer room creation, joining, host transfer, start flow, score relay, and completion
- score submission and stats persistence
- in-game registration and essential `/web/*` endpoints

The goal is practical client compatibility, not a line-by-line clone of official osu! infrastructure or of bancho.py internals.

## Tech Stack

- **LuaJIT 2.1** runtime
- **OpenResty / sea** HTTP resource model for protocol and `/web/*` endpoints
- **SQLite via `aqua/rdb`** for persistence
- **Shared dict backed collections** for cross-worker online state
- **LÖVE project integration** so the module fits the rest of this repository

## Module Shape

Important folders:

- `bancho/protocol/` — packet encoding/decoding and compound protocol types
- `bancho/handler/` — packet router and packet handlers
- `bancho/model/` — online session models and shared-state collections
- `bancho/server/` — central runtime wiring (`BanchoServer`)
- `bancho/http/` — Bancho protocol and osu web resources
- `bancho/db/` — SQLite schema, models, and repos
- `bancho/multiplayer/` — room lifecycle logic
- `bancho/chat/` — channels and messaging
- `bancho/score/` — score submission and chart response logic
- `bancho/client/` — test client / protocol client used by E2E tests and integrations
- `bancho/config/` — config model and example config
- `bancho/e2e/` — end-to-end tests grouped by behavior area

## Architecture Decisions

### Bancho is request-driven HTTP, not a long-lived socket server

Client communication is modeled around Bancho HTTP requests:

- login request without `osu-token`
- packet exchange requests with `osu-token`
- `/web/*` HTTP endpoints for score submission and related flows

This keeps the implementation aligned with actual osu! client behavior and with the repository's existing web stack.

### `BanchoServer` is the composition root

`bancho.server.BanchoServer` wires together:

- collections
- packet router
- command dispatcher
- managers
- repos
- config

Handlers and resources should depend on the server object and repos instead of constructing their own independent state.

### Shared online state is separate from persisted state

Online runtime state lives in shared collections so multiple OpenResty workers can see the same sessions, matches, and channels.

Persisted state lives in SQLite and repos.

This split is intentional.

## ADR: DB-Only Persisted User Fields

### Decision

Persisted user data stays DB-owned and is not mirrored into shared `Player` session state.

### Why

bancho.py often keeps more user/profile data on live player objects. In this port, online state is also serialized through shared dicts for cross-worker visibility. Copying DB-backed fields into `Player` would create two sources of truth:

- SQLite rows and repos
- shared session snapshots

That makes correctness worse, especially across requests and workers.

### Consequences

`bancho.model.Player` should contain session/runtime data only, such as:

- token
- online status
- current action/map/mods/mode
- silence state for the active session
- spectating links
- match membership
- packet queue

The following remain DB-owned and should be read through repos when needed:

- friends / friend relations
- PM privacy
- away message
- presence filter
- UTC offset and similar persisted preference fields

### Difference from bancho.py

This is a deliberate divergence from bancho.py. The Lua port prefers a stricter single-source-of-truth model because session objects are shared across workers.

## Data Layer

### Persisted data

SQLite schema and repos in `bancho/db/` are the source of truth for:

- users
- stats
- beatmaps
- scores
- friends
- favourites
- replays

Main repos:

- `UserRepo`
- `StatsRepo`
- `ScoreRepo`
- `BeatmapRepo`
- `FriendsRepo`
- `FavouritesRepo`
- `ReplayRepo`

### Shared runtime data

Shared dict backed collections are used for cross-worker online state:

- `PlayerCollection`
- `MatchCollection`
- `ChannelCollection`

These collections store runtime/session objects and packet queues, not durable profile data.

## Configuration

Configuration is centered on `bancho.config.BanchoConfig` and local `bancho/config.lua` overrides.

Important config areas:

- domain / host identity
- bot identity
- DB path
- storage paths for beatmaps, replays, screenshots
- multiplayer limits
- registration toggles
- command prefix
- menu icon links
- seasonal backgrounds
- default channels
- mirror endpoints

Runtime overrides may be passed into `BanchoServer:new(...)` for tests or special setups.

## HTTP Resources

Important resources:

- `BanchoProtocolResource` — login, packet exchange, debug pages
- `OsuWebResource` — `/web/*` endpoints needed by clients
- `FileResource` — screenshots, downloads, map file serving
- `AccountResource` — in-game registration

These are integrated through the `sea` resource model and domain-based routing.

## Multiplayer Model

Multiplayer logic is split between:

- `bancho.model.Match`
- `bancho.multiplayer.MatchManager`
- packet handlers under `bancho/handler/`
- chat/channel integration for match rooms

The implementation aims for client-visible parity on the flows we use, while keeping the internal model simple and explicit.

## Testing Strategy

Tests are behavior-first.

- unit tests cover protocol, repos, managers, handlers, and collections
- E2E tests under `bancho/e2e/` cover real request/response flows using the local Bancho client and fake transport
- E2E coverage is split by concern:
  - login
  - messaging
  - spectating
  - multiplayer
  - commands
  - social
  - score submission
  - registration
  - HTTP

When behavior changes, prefer updating or adding focused E2E coverage for client-visible flows.

## Current Non-Goals

For now, this spec does not try to document the full osu server ecosystem or every official endpoint in detail.

Lower-priority or partial areas include:

- tournament-specific flows
- full moderation/admin feature parity
- full anti-cheat parity
- offline mail / broader social systems
- full web/frontend ecosystem outside the client flows we need

## Working Rules For Future Changes

- Prefer client-visible compatibility over copying bancho.py internals.
- Keep persisted user data in repos/DB, not duplicated in shared session models.
- Keep online cross-worker state in shared collections.
- Prefer small, explicit handlers and managers over hidden implicit coupling.
- Add E2E coverage when fixing real-client regressions.
