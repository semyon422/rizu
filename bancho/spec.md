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
- **Sea server SQLite schema via `aqua/rdb`** for persistence
- **Shared dict backed collections** for cross-worker online state
- **LÖVE project integration** so the module fits the rest of this repository

## Module Shape

Important folders:

- `bancho/protocol/` — packet encoding/decoding and compound protocol types
- `bancho/handler/` — packet router and packet handlers
- `bancho/model/` — online session models and shared-state collections
- `bancho/server/` — central runtime wiring (`BanchoServer`)
- `bancho/http/` — Bancho protocol and osu web resources
- `bancho/adapter/` — Sea-backed repository adapters for Bancho compatibility
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

Persisted state lives in the Sea server DB and Bancho adapter repos.

This split is intentional.

## ADR: DB-Only Persisted User Fields

### Decision

Persisted user data stays DB-owned and is not mirrored into shared `Player` session state.

### Why

bancho.py often keeps more user/profile data on live player objects. In this port, online state is also serialized through shared dicts for cross-worker visibility. Copying DB-backed fields into `Player` would create two sources of truth:

- Sea DB rows and repos
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

Sea-backed persistence and adapter repos are the source of truth for:

- users and Bancho credentials
- Bancho user settings and stats
- beatmap identity bridging
- canonical score / replay persistence
- friends
- favourites

Main adapter repos:

- `SeaUserRepo`
- `SeaStatsRepo`
- `SeaScoreRepo`
- `SeaBeatmapRepo`
- `SeaFriendsRepo`
- `SeaFavouritesRepo`
- `SeaReplayRepo`

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

## Adapter Direction: Bancho As A Rizu/Sea Adapter

### Goal

The long-term direction is to make `bancho/` an adapter layer for the Rizu server in `sea/`, not a separate standalone server with its own persistent database.

In practice this means:

- osu! clients connect through Bancho-compatible HTTP and packet endpoints from `bancho/`
- account ownership, persistent user data, and long-term server state belong to `sea/`
- Bancho keeps protocol translation and client-compatibility behavior
- Bancho may keep transient runtime state in shared memory for online sessions, channels, and active matches
- Bancho should not require its own SQLite database file once the adapter migration is complete

### User Experience

From an osu! client point of view, the server should still look like a Bancho-compatible server:

- login with osu! client flows
- presence, chat, and multiplayer work through Bancho packets
- `/web/*` osu! endpoints continue to exist where needed
- score and leaderboard behavior should resolve against Rizu-owned data where supported

From the repository point of view, the Bancho module becomes a compatibility surface for osu! clients rather than a second account platform.

### Migration Principle

Move persistence into `sea/` first, keep protocol/runtime adaptation in `bancho/`, and only then reduce duplicated models and flows where it is safe.

The existing `BanchoServer:setRepos(...)` seam is the preferred migration hook. `BanchoServer` should continue to depend on explicit repository interfaces, and the backing implementations should come from `sea/`.

## Architecture Decisions

### ADR: Bancho Owns Protocol Translation, Sea Owns Persistence

Bancho remains responsible for:

- Bancho HTTP resources
- packet parsing and serialization
- session-facing compatibility logic
- transient online runtime models such as online player sessions, channels, and active Bancho matches

Sea owns:

- users and credentials
- persistent profile data
- long-term score / replay / leaderboard data
- beatmap metadata storage
- cross-feature server policy and account lifecycle

This preserves Bancho compatibility without keeping two persistent account systems.

### ADR: No Separate Bancho DB File

The target architecture should not require `bancho.db` or another Bancho-owned SQLite database file.

Bancho-specific persistent data that still needs to exist during or after migration should live in the `sea` database schema and be accessed through adapter repos. Examples may include:

- Bancho login credential material
- friends / favourites
- PM privacy and away-message preferences
- Bancho-oriented score compatibility tables, if direct reuse of existing `sea` score models is not yet sufficient

### ADR: Shared Runtime State Is Allowed

"Bancho has no own DB" does not forbid shared-memory runtime state.

The current shared dict collections for:

- online Bancho players
- active Bancho matches
- Bancho channels

are still acceptable because they are transient online state, not a second durable persistence layer.

### ADR: Mania-First Compatibility

The first adapter milestone should target osu!mania compatibility before broader Bancho parity.

Reasons:

- the repository already has strong mania-oriented chart and replay infrastructure
- `sea` gamemode coverage is narrower than Bancho's full mode matrix
- score translation risk is much lower for mania than for osu!/taiko/catch

Unsupported modes should be explicitly deferred rather than partially and silently mis-modeled.

## Incompatibilities To Solve

### Authentication

Current mismatch:

- Bancho login uses `username + md5(password)` from the osu! client
- `sea` login uses `email + plaintext password`
- Bancho currently verifies against `bcrypt(md5(password))`
- `sea` currently verifies against its normal password hash

Consequence:

Bancho cannot simply call the existing `sea.Users:login()` path.

Required solution:

- add Bancho-compatible credential storage or derivation in `sea`
- keep password updates synchronized
- provide adapter repo methods for Bancho username-based login
- prefer a Sea-owned `bancho_credentials` persistence object over overloading the main Sea password field

### User / Privilege Model

Current mismatch:

- Bancho expects Bancho privilege bits, restriction flags, silence state, PM preferences, away message, and presence preferences
- `sea` users expose a different role and profile model

Required solution:

- map `sea` roles and bans into Bancho privilege bits
- persist Bancho-specific preferences in `sea`
- keep Bancho session state runtime-only where possible

### Multiplayer

Current mismatch:

- Bancho multiplayer is an osu!-style 16-slot match protocol with host transfer, team rules, freemods, loading state, and score relay
- `sea.Multiplayer` models simpler Rizu rooms and synchronization

Required solution:

- do not force Bancho matches onto `sea.Multiplayer` in the first migration
- keep Bancho match runtime in `bancho/` shared state
- integrate only at the account and persistence boundaries initially

### Chat And Social Features

Current mismatch:

- Bancho requires public channels, PMs, friends, favourites, away message, and PM privacy behavior
- `sea` has online/broadcast infrastructure but not Bancho-equivalent persistent social storage

Required solution:

- keep Bancho channel and PM runtime behavior in `bancho/`
- move persistent social/settings data into `sea` schema and repos

### Score Submission And Leaderboards

Current mismatch:

- Bancho score submission is osu-specific and keyed by beatmap md5, vanilla modes, and Bancho response formats
- `sea` chartplay submission is chart-centric and uses `hash + index` with richer replay and leaderboard models

Required solution:

- build an adapter/translator, starting with mania
- map Bancho beatmap identity to `sea` beatmap/chart metadata
- either submit into existing `sea` chartplay flows where feasible or use Sea-owned Bancho-compatibility tables as an intermediate phase

### Gamemodes

Current mismatch:

- Bancho models osu, taiko, catch, mania, relax, and autopilot variants
- `sea` currently models a smaller set of gameplay modes

Required solution:

- scope first delivery to mania
- document unsupported modes explicitly

## Phased Implementation Plan

### Phase 0 — Save And Approve Scope

- keep this spec updated as the source of truth for the migration
- explicitly define first supported client flows
- explicitly define first unsupported flows
- prefer mania-only scope for the first working adapter milestone

### Phase 1 — Stop Wiring Bancho To Its Own SQLite DB

- construct Sea-backed adapter repos and inject them via `BanchoServer:setRepos(...)`
- keep Bancho runtime boot free of any Bancho-owned DB wrapper
- use Sea server DB fixtures in tests as well as production

Definition of done:

- Bancho endpoints boot inside `sea` without opening `bancho.db`
- repository interfaces are still explicit
- no client-visible behavior is intentionally changed yet beyond persistence ownership

### Phase 2 — Build Auth And User Adapters

- add Sea-backed Bancho user repo implementation
- add Sea-side storage for Bancho-compatible login credentials
- introduce a Sea-owned `bancho_credentials` table or equivalent persistence object for `bcrypt(md5(password))`
- map Sea user roles / bans into Bancho privileges and restriction state
- decide whether Bancho in-game registration is disabled initially or bridged into Sea registration

Definition of done:

- osu! client login resolves against Sea-owned users
- no Bancho user row is required in a separate DB
- Bancho user settings updates persist into Sea-owned storage

### Phase 3 — Persist Bancho-Specific Preferences And Social Data In Sea

- add Sea-backed repos for friends, favourites, and session preference persistence
- keep runtime session fields on `bancho.model.Player`
- move durable preference fields out of Bancho-owned persistence

Definition of done:

- Bancho no longer depends on Bancho-owned `friends`, `favourites`, or user preference tables
- PM/privacy/away-message behavior has a Sea-owned backing store

### Phase 4 — Keep Bancho Runtime Online State, Not Sea Multiplayer Reuse

- retain shared dict collections for Bancho online players, channels, and active matches
- do not rewrite Bancho multiplayer onto `sea.Multiplayer` yet
- document the separation clearly so later work does not collapse incompatible models prematurely

Definition of done:

- Bancho multiplayer remains functional as a protocol runtime
- persistence migration does not regress match behavior

### Phase 5 — Beatmap Identity Bridge

- implement Sea-backed beatmap repo adapter
- reuse `sea.osu` and existing chart metadata where possible
- maintain mapping between Bancho beatmap md5 and Sea chart/beatmap identity
- keep local `.osu` loading only as a supporting data source, not as proof that Bancho owns persistence

Definition of done:

- Bancho beatmap lookups no longer require Bancho-owned beatmap storage
- beatmap status and identity are resolved from Sea-owned data paths

### Phase 6 — Mania Score And Leaderboard Bridge

- implement Bancho score submission against Sea-owned persistence
- start with osu!mania only
- use canonical Sea chartplay + replay storage for submitted plays
- convert uploaded `.osr` replays into canonical Sea/Rizu replays on submission
- serve Bancho-compatible replay downloads by converting canonical Sea/Rizu replays back into `.osr` on demand
- expose Bancho leaderboard responses from Sea-backed data, including synthesized or stubbed Bancho views from canonical chartplays where needed

Definition of done:

- osu!mania score submission and basic leaderboard flows work without Bancho SQLite
- submitted osu replays become visible and replayable in Rizu via canonical Sea replay storage
- Bancho replay downloads work from canonical Sea replay storage via on-demand conversion
- replay persistence is Sea-owned
- unsupported non-mania modes fail explicitly

### Phase 7 — Expand Or Formalize Deferred Areas

Evaluate and either implement or explicitly defer:

- in-game registration
- comments / mail / ratings endpoints
- broader social parity
- non-mania modes
- deeper convergence between Bancho runtime multiplayer and Sea multiplayer concepts

## First Practical Milestone

The recommended first milestone is:

- Bancho runs as part of `sea`
- Bancho opens no separate SQLite database
- osu! client login resolves against Sea-owned users
- presence, chat, and Bancho multiplayer runtime still work
- unsupported score and leaderboard areas are explicitly limited rather than silently incorrect

This is the safest path to a real adapter foundation.

## Current Non-Goals

For now, this spec does not try to document the full osu server ecosystem or every official endpoint in detail.

Lower-priority or partial areas include:

- tournament-specific flows
- full moderation/admin feature parity
- full anti-cheat parity
- offline mail / broader social systems
- full web/frontend ecosystem outside the client flows we need
- full non-mania parity in the first adapter milestone
- collapsing Bancho multiplayer directly into `sea.Multiplayer` before compatibility constraints are understood

## Working Rules For Future Changes

- Prefer client-visible compatibility over copying bancho.py internals.
- Keep persisted user data in repos/DB, not duplicated in shared session models.
- Keep online cross-worker state in shared collections.
- Prefer small, explicit handlers and managers over hidden implicit coupling.
- Add E2E coverage when fixing real-client regressions.
