# Bancho Module

## Goal

Implement the osu! server-side protocol and internal systems in Lua under the `bancho` namespace, reimagining [bancho.py](https://github.com/peppy/bancho) as a Lua module that runs inside the LÖVE-based game client.

---

## What Is Implemented

### Protocol Layer (`bancho/protocol/`)

Complete binary protocol implementation for the Bancho packet format (7-byte header: `u16` id + `u8` padding + `u32` body length).

- **Binary.lua** — Low-level read/write for all primitive types: `i8/u8/i16/u16/i32/u32/i64/u64/f32/f64`, ULEB128, length-prefixed strings (`0x0B` + ULEB128 length + UTF-8), and `i32_list` (u16 length + i32 elements).
- **PacketReader.lua** — Streaming reader that wraps Binary with position tracking (`readI32()`, `readString()`, etc.).
- **PacketWriter.lua** — Accumulating writer with `finalize(id)` to attach the packet header.
- **ComplexTypes.lua** — Readers and writers for the four compound Bancho types: `MultiplayerMatch`, `ScoreFrame`, `ReplayFrameBundle`, `Message`, `Channel`.
- **ClientPackets.lua** — All client→server packet IDs (0, 1, 2, 3, 4, 16, 17, 18, 31, 32, 33, 39, 44, 47, 49, 63, 78).
- **ServerPackets.lua** — All server→client packet constructors: `loginReply`, `sendMessage`, `pong`, `notification`, `userStats`, `userPresence`, `userLogout`, `spectatorJoined/Left`, `spectateFrames`, `updateMatch`, `matchJoinSuccess/Fail`, `disposeMatch`, `channelJoin/Info/Kick/AutoJoin`, `banchoPrivileges`, `friendsList`, `matchScoreUpdate`, `matchComplete`, `protocolVersion`, `channelInfoEnd`.

### Domain Models (`bancho/model/`)

- **Player.lua** — Online player state: ID, name, privileges, token, status (action, map, mods, mode), per-mode stats (tscore, rscore, pp, acc, plays, playtime, max_combo, rank, grades), packet queue with enqueue/dequeue, silence tracking, and client privilege derivation.
- **PlayerCollection.lua** — In-memory registry indexed by token, ID, and safe name. Supports `get`, `add`, `remove`, `ids`, `staff`, `enqueue` (broadcast with immune list).
- **Match.lua** — 16-slot multiplayer room with settings (map, mode, mods, freemods, win condition, team type), slot management (player, status, team, mods, loaded), and helper methods (`getSlot`, `getFree`, etc.).
- **MatchCollection.lua** — Fixed-size match registry (default 64) with `get`, `getFree`, `add`, `remove`, `all`.
- **Channel.lua** — Chat channel with name, topic, player set, read/write privilege checks, auto-join, and instance (auto-delete) flags.
- **ChannelCollection.lua** — Channel registry indexed by name with `get`, `add`, `remove`, `sendTo`, `all`.
- **Score.lua** — Score data model with `fromSubmission()` parser (colon-delimited format), per-mode accuracy calculation (osu!, taiko, catch, mania with ScoreV2 support), and grade handling.
- **Beatmap.lua** — Beatmap metadata: md5, id, set_id, artist, title, version, creator, total_length, max_combo, status, mode, bpm, CS/OD/AR/HP, star rating. Methods: `fullName`, `hasLeaderboard`, `awardsRankedPP`.

### Business Logic

- **auth/LoginHandler.lua** — Login request parser: splits `username\npassword_md5\nosu_version|utc_offset|display_city|client_hashes|pm_private\n`, parses osu version string (`bYYYYMMDDrNstream`), parses client hashes, returns structured `LoginData`. Includes anti-cheat adapter string check.
- **score/Submitter.lua** — Score submission processing: `calculateStatus()` (BEST vs SUBMITTED comparison), map ranking checks (`mapAwardsRankedPP`, `mapHasLeaderboard`), online checksum computation (stub).
- **multiplayer/MatchManager.lua** — Full match lifecycle: create, add/remove player, ready, mods, team, loaded, start, complete, fail, transfer host, change password, dispose, build protocol match data.
- **chat/ChatManager.lua** — Chat operations: create/join/leave channels, send public/private/bot messages, kick, notify, broadcast, auto-join, and full login message flow (privileges → friends list → protocol version → channel info → channel info end → auto-join).

### Cryptography (`bancho/crypto/`)

- **ScoreCrypto.lua** — Score encryption/decryption stub (XOR-based for testing). Documents the real algorithm: Rijndael-256 CBC with PKCS7 padding, key = `"osu!-scoreburgr---------{osu_version}"`.

### Constants (`bancho/constants/`)

Complete constant sets: `Action`, `ClientFlags`, `ClientPrivileges`, `GameMode` (with relax/autopilot variants and `fromParams`), `Grade`, `LoginFailureReason`, `MatchConstants` (win conditions, team types, teams), `Mods` (with `filterInvalidCombos`, `fromModString`, `toString`), `Privileges`, `RankedStatus`, `ReplayAction`, `SlotStatus`, `SubmissionStatus`.

### Stubs (`bancho/stub/`)

Test doubles for external dependencies: `BcryptHasher`, `Repo` (users/scores/beatmaps), `HttpClient`, `GeoLocator`, `PerformanceCalculator`.

### Tests

Every module has a corresponding `_test.lua` file covering core behavior.

---

## What Is Needed For A Fully Working osu! Server

The code above covers the protocol layer, domain models, and business logic in isolation. To become a production-ready osu! server, the following pieces are still needed:

### 1. TCP/HTTP Server (Transport Layer)

The Bancho protocol uses HTTP POST with token-based session management, not raw TCP. The server needs:

- **HTTP endpoint for `/` (Bancho)** — Accepts POST requests. On login (no `osu-token` header), returns `cho-token` header + binary packet body. On subsequent requests, validates `osu-token` header, drains the player's packet queue, and processes incoming packets.
- **WebSocket or long-polling fallback** — Some mirrors use WebSocket for real-time packet delivery. The current packet queue model (enqueue/dequeue on each POST) is the standard Bancho approach.
- **Integration with LÖVE's networking** — Since this runs inside the LÖVE game client, the server likely needs to bridge between LÖVE's socket API and the Bancho protocol. This is the key architectural decision: whether the bancho module runs as a standalone Lua server (using LuaSocket or similar) or as a component within the game's existing network layer.

### 2. Real Database Backend

All current "repositories" are in-memory stubs. A real server needs:

- **User table** — `id`, `name`, `password` (bcrypt hash), `privileges`, `country_acronym`, `country_code`, `silence_end`, `token`, `client_hashes` (path_md5, adapters_md5, uninstall_md5, disk_signature_md5).
- **Stats table** — Per-mode stats: `user_id`, `mode`, `tscore`, `rscore`, `pp`, `acc`, `plays`, `playtime`, `max_combo`, `rank`, grade counts (xh, x, sh, s, a).
- **Scores table** — `id`, `map_md5`, `score`, `pp`, `acc`, `max_combo`, `mods`, hit counts (n300, n100, n50, nmiss, ngeki, nkatu), `grade`, `status` (SubmissionStatus), `mode`, `play_time`, `time_elapsed`, `client_flags`, `user_id`, `perfect`, `online_checksum`.
- **Beatmaps table** — `id`, `set_id`, `md5`, `filename`, `artist`, `title`, `version`, `creator`, `total_length`, `max_combo`, `status`, `mode`, `bpm`, `cs`, `od`, `ar`, `hp`, `diff` (star rating), `plays`, `passes`.
- **Scores-Friends/Following table** — For friends list, friend presence requests.
- **Mail table** — In-game mail system.
- **Achievements tables** — Server achievement definitions and per-user unlocked achievements.
- **Ratings table** — Per-user beatmap ratings.
- **Favourites table** — Per-user favourited beatmap sets.
- **Logs table** — In-game login logs, moderation logs, chat logs.
- **Clans tables** — Clan definitions, clan members, clan tags.

**Database choice**: Could use SQLite (simple, embedded, good for single-server setups), MySQL/MariaDB (bancho.py default, good for multi-instance), or any SQL backend with a Lua driver. The `stub/Repo` pattern already abstracts this.

### 3. Real Rijndael-256 Implementation

`bancho/crypto/ScoreCrypto.lua` currently uses XOR stub encryption. The real score submission endpoint requires:

- **Rijndael-256 CBC** with PKCS7 padding for decrypting the `score` form parameter.
- **Key derivation**: `"osu!-scoreburgr---------{osu_version}"` (padded to 32 bytes).
- **IV**: Provided by the client in the `iv` form parameter (base64).
- This could use LuaJIT FFI to call into a C library (libmbedcrypto, OpenSSL, or a standalone Rijndael implementation) or a pure-Lua port.

### 4. Web API Endpoints

The osu! client makes HTTP requests to several endpoints beyond the Bancho protocol:

- **`POST /web/osu-submit-modular.php`** — Main score submission endpoint. Receives multipart form data with encrypted score, replay file, IV, password, osu version, client hash, unique IDs. Must: decrypt score, verify checksums, look up beatmap and player, calculate PP/accuracy, store score, update stats, return submission charts.
- **`POST /web/osu-submit-modular-selector.php`** — Variant used by newer clients with active session tokens. Same core logic but authenticated via `token` header instead of password.
- **`GET /web/osu-osz2-getscores.php`** — Leaderboard endpoint. Returns ranked status, beatmap metadata, and up to 50 scores in pipe-delimited format. Supports leaderboard types: Top, Mods, Friends, Country, Local.
- **`GET /web/osu-getreplay.php`** — Serve `.osr` replay files by score ID.
- **`GET /web/osu-getfriends.php`** — Return newline-delimited friend IDs.
- **`POST /web/osu-getbeatmapinfo.php`** — Beatmap info lookup by filename or ID. Returns map ID, set ID, MD5, status, and per-mode grades.
- **`GET /web/osu-search.php`** — Beatmap search (proxies to osu! API mirror). Returns osu!Direct format.
- **`GET /web/osu-search-set.php`** — Beatmap set detail lookup.
- **`GET /web/osu-getfavourites.php`** — Return favourited set IDs.
- **`GET /web/osu-addfavourite.php`** — Add beatmap set to favourites.
- **`GET /web/lastfm.php`** — Anti-cheat endpoint. Client sends hidden flags that detect modified clients (hq!osu, AQN). Returns empty or triggers restriction.
- **`POST /web/osu-screenshot.php`** — Screenshot upload endpoint.
- **`GET /web/osu-rate.php`** — Beatmap rating submission and retrieval.

### 5. Performance Calculation (PP/SR)

`bancho/stub/PerformanceCalculator.lua` returns fixed values. A real server needs:

- **Star Rating (SR) calculation** — Parse `.osu` beatmap files to compute difficulty rating based on circle spacing, approach rate, note density, etc. This is complex mode-specific math.
- **Performance Points (PP) calculation** — Compute PP from score data + beatmap difficulty. Different formulas per game mode (osu!std, taiko, catch, mania). The official formula is documented in the osu! wiki and implemented in the `baton` (C++) library.
- **Options**: (a) FFI binding to `baton` C++ library, (b) HTTP call to a PP calculation microservice, (c) pure-Lua port of the algorithm.

### 6. Beatmap File Management

- **`.osu` file storage** — Beatmap files need to be stored on disk (typically in `.data/osz2/` or similar) for replay playback and PP calculation.
- **`.osz`/`.osz2` archive handling** — Download and extract beatmap sets from the osu! API or manual upload.
- **Beatmap mirror integration** — Sync beatmap metadata from `https://osu.ppy.sh/` or a mirror (like `quasibit` or `flyingshots`). The `MIRROR_SEARCH_ENDPOINT` setting controls this.
- **File serving** — Serve `.osz2` files to clients for download during multiplayer matches.

### 7. Packet Router / Command Dispatcher

The current code has managers but no central packet router. Need:

- **Packet dispatch loop** — Parse incoming binary data, read headers, dispatch to handlers by packet ID. The bancho.py pattern uses a `BanchoPacketReader` iterator with a `PacketMap` dictionary.
- **Packet handlers** — One handler class per client packet (e.g., `ChangeAction`, `SendPublicMessage`, `Logout`, `Ping`, `StartSpectating`, `CreateMatch`, `JoinMatch`, etc.). Each handler reads its body from the PacketReader and delegates to the appropriate manager.
- **Spectator system** — Track spectator relationships, forward replay frames from watched player to watchers, handle fellow-spectator join/leave notifications.
- **Multiplayer packet relay** — During active matches, relay `MATCH_SCORE_UPDATE` frames between players, handle `MATCH_ALL_PLAYERS_LOADED`, `MATCH_COMPLETE`, `MATCH_SKIP`, etc.

### 8. Anti-Cheat System

- **Client hash verification** — On login, store and verify client file hashes (path MD5, adapters, uninstall, disk signature).
- **Score checksum validation** — On score submission, compute the online checksum and compare with client-provided value.
- **Last.fm anti-cheat** — Parse the hidden flags sent via `/web/lastfm.php` to detect hq!osu, AQN, and other modified clients.
- **Restrict/ban system** — Ability to restrict players (kick from server, mark account), with reason tracking and admin tools.
- **Silence system** — Time-limited chat silences with expiry tracking.

### 9. Background Tasks

- **Periodic rank recalculation** — Global and country ranks need periodic updates based on PP.
- **Session cleanup** — Remove stale/disconnected players.
- **Match cleanup** — Dispose abandoned matches after timeout.
- **Presence broadcast** — Periodically broadcast `USER_PRESENCE` updates.
- **Bot status rotation** — The bot player's status should periodically change.

### 10. Configuration / Settings

- **Server settings module** — Domain, database connection strings, mirror endpoints, bot configuration, feature flags (e.g., enable restrictions, enable PP calculation).
- **Environment variable support** — Mirror bancho.py's `.env` pattern for configuration.

### 11. Moderation / Admin Commands

bancho.py has an extensive in-game command system (`/ban`, `/unban`, `/silence`, `/unsilence`, `/rename`, `/broadcast`, `/map`, `/host`, `/skip`, etc.). These need:

- **Command parser** — Parse `/command args` from chat messages.
- **Command registry** — Privilege-gated command handlers.
- **Match commands** — `/host`, `/skip`, `/ready`, `/fr`, `/nomod`, `/auto`, etc.
- **Admin commands** — `/ban`, `/unban`, `/silence`, `/rename`, `/broadcast`, `/map`, `/setmod`, etc.

### 12. Additional Features From bancho.py

- **Clans** — Clan creation, membership, tags, clan channels.
- **Achievements** — Server-defined achievement conditions, per-user unlock tracking, achievement notifications on score submission.
- **Map requests** — Users can request maps be added to the server's library.
- **Tourney pools** — Tournament map pool management.
- **Discord integration** — Rich presence, status updates.
- **API v2** — REST API for web frontend (player profiles, score listings, clan pages, map pages).
- **Multi-region endpoint support** — `SWITCH_SERVER` packet for failover between server instances.

---

## Architecture Notes

### Module Organization

```
bancho/
  protocol/     — Binary protocol (packets, serialization)
  model/        — Domain objects (Player, Match, Score, etc.)
  auth/         — Authentication (login parsing, validation)
  score/        — Score submission processing
  multiplayer/  — Match lifecycle management
  chat/         — Chat and channel management
  crypto/       — Encryption/decryption
  constants/    — Enums and bitmasks
  stub/         — Test doubles for external dependencies
```

### Design Principles

- **Stub-driven**: External dependencies (database, crypto, HTTP, geolocation, PP calculation) are abstracted behind stubs. This allows full unit testing without infrastructure.
- **Packet queue model**: Each player has an internal packet queue. Managers enqueue packets; the transport layer drains them on each client request.
- **In-memory collections**: `PlayerCollection`, `MatchCollection`, `ChannelCollection` provide in-memory registries. For production, these would be backed by or synchronized with a database.
- **LuaJIT FFI**: Used for binary operations (float conversion, LEB128). Should also be used for crypto (Rijndael-256) and potentially PP calculation (baton binding).

### Integration With The Game Client

This module is designed to run inside the LÖVE-based game client. The key integration points are:

1. **Networking**: The transport layer needs to connect to LÖVE's `love.socket` or the project's existing network infrastructure.
2. **Shared memory / IPC**: If the server runs in a separate thread or process, inter-process communication is needed for state sharing.
3. **Asset access**: Beatmap files and replay files need to be accessible from the game's file system.
