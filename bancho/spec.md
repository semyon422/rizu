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

- **Player.lua** — Online session state: ID, name, privileges, token, status (action, map, mods, mode), packet queue with enqueue/dequeue, silence tracking, spectating links, multiplayer membership, and client privilege derivation. Persisted profile data is not mirrored into `Player`.
- **PlayerCollection.lua** — In-memory registry indexed by token, ID, and safe name. Supports `get`, `add`, `remove`, `ids`, `staff`, `enqueue` (broadcast with immune list).
- **Match.lua** — 16-slot multiplayer room with settings (map, mode, mods, freemods, win condition, team type), slot management (player, status, team, mods, loaded), and helper methods (`getSlot`, `getFree`, etc.).
- **MatchCollection.lua** — Fixed-size match registry (default 64) with `get`, `getFree`, `add`, `remove`, `all`.
- **Channel.lua** — Chat channel with name, topic, player set, read/write privilege checks, auto-join, and instance (auto-delete) flags.
- **ChannelCollection.lua** — Channel registry indexed by name with `get`, `add`, `remove`, `sendTo`, `all`.
- **Score.lua** — Score data model with `fromSubmission()` parser (colon-delimited format), per-mode accuracy calculation (osu!, taiko, catch, mania with ScoreV2 support), grade handling, `computeOnlineChecksum()` for score tamper detection (MD5 of chickenmcnuggets salted string), and `calculatePP(beatmap)` for performance points (mania via `chart/scoring/osu_pp.lua`).
- **Beatmap.lua** — Beatmap metadata: md5, id, set_id, artist, title, version, creator, total_length, max_combo, status, mode, bpm, CS/OD/AR/HP, star rating. Methods: `fullName`, `hasLeaderboard`, `awardsRankedPP`.

### Business Logic

- **auth/LoginHandler.lua** — Login request parser: splits `username\npassword_md5\nosu_version|utc_offset|display_city|client_hashes|pm_private\n`, parses osu version string (`bYYYYMMDDrNstream`), parses client hashes, returns structured `LoginData`. Includes anti-cheat adapter string check.
- **score/Submitter.lua** — Score submission processing: `submit()` (score parsing, accuracy calculation, PP calculation via `Score:calculatePP()`, checksum validation via `Score:computeOnlineChecksum()`, score persistence, stats updates, chart response generation), `calculateStatus()` (BEST vs SUBMITTED comparison), map ranking checks (`mapAwardsRankedPP`, `mapHasLeaderboard`).
- **score/Chart.lua** — Score submission chart response generator. Produces pipe-delimited chart string with beatmap info, beatmap ranking (before/after), and overall ranking (before/after) sections.
- **multiplayer/MatchManager.lua** — Full match lifecycle: create, add/remove player, ready, mods, team, loaded, start, complete, fail, transfer host, change password, dispose, build protocol match data.
- **chat/ChatManager.lua** — Chat operations: create/join/leave channels, send public/private/bot messages, kick, notify, broadcast, auto-join, and full login message flow (privileges → friends list → protocol version → channel info → channel info end → auto-join).

### Cryptography (`bancho/crypto/`)

- **ScoreCrypto.lua** — Score encryption/decryption: `decryptScore()` (decrypts score data + client hash separately), `encrypt()`/`decrypt()` (Rijndael-256 CBC with PKCS7 padding via OpenSSL FFI). Key = `"osu!-scoreburgr---------{osu_version}"` (32 bytes).
- **Rijndael.lua** — OpenSSL FFI bindings for AES-256-CBC: `encrypt()` (plaintext → base64 ciphertext), `decrypt()` (base64 ciphertext → plaintext), `deriveKey()` (osu version → 32-byte key).

### Constants (`bancho/constants/`)

Complete constant sets: `Action`, `ClientFlags`, `ClientPrivileges`, `GameMode` (with relax/autopilot variants and `fromParams`), `Grade`, `LoginFailureReason`, `MatchConstants` (win conditions, team types, teams), `Mods` (with `filterInvalidCombos`, `fromModString`, `toString`), `Privileges`, `RankedStatus`, `ReplayAction`, `SlotStatus`, `SubmissionStatus`.

### Packet Handlers (`bancho/handler/`)

Central packet router and handler classes. Each handler inherits `IPacketHandler` via `class()` and implements `parse(reader, bodyLen)` and `handle(server, player, data)`.

- **IPacketHandler.lua** — Base class defining the handler interface. Subclasses inherit via `IPacketHandler + {}`.
- **PacketRouter.lua** — Maintains two handler registries (`handlers_all` for unrestricted players, `handlers_restricted` for restricted players). The dispatch loop reads packet headers, looks up the handler in the correct registry, calls `handler:parse()` then `handler:handle()`.
- **init.lua** — Registers all 46 handlers with the router at server startup.

Handler classes (all inherit `IPacketHandler`, all use `function Class:parse(reader, bodyLen)` and `function Class:handle(server, player, data)`):

| Handler | Packet ID | Data Type | Restricted? |
| :--- | :---: | :--- | :---: |
| Ping | 4 | `PingData` (empty) | ✓ |
| ChangeAction | 0 | `ChangeActionData` | ✓ |
| Logout | 2 | `LogoutData` (empty) | ✓ |
| StatusUpdateRequest | 3 | `StatusUpdateRequestData` (empty) | ✓ |
| SendPublicMessage | 1 | `bancho.protocol.Message` | — |
| SendPrivateMessage | 25 | `bancho.protocol.Message` | — |
| StartSpectating | 16 | `StartSpectatingData` | — |
| StopSpectating | 17 | `StopSpectatingData` (empty) | — |
| SpectateFrames | 18 | `SpectateFramesData` | — |
| CantSpectate | 21 | `CantSpectateData` (empty) | — |
| PartLobby | 29 | `PartLobbyData` (empty) | — |
| JoinLobby | 30 | `JoinLobbyData` (empty) | — |
| ChannelJoin | 63 | `ChannelJoinData` | ✓ |
| ChannelPart | 78 | `ChannelPartData` | ✓ |
| CreateMatch | 31 | `CreateMatchData` | — |
| JoinMatch | 32 | `JoinMatchData` | — |
| PartMatch | 33 | `PartMatchData` (empty) | — |
| MatchChangeSlot | 38 | `MatchChangeSlotData` | — |
| MatchReady | 39 | `MatchReadyData` (empty) | — |
| MatchLock | 40 | `MatchLockData` | — |
| MatchChangeSettings | 41 | `bancho.protocol.MultiplayerMatch` | — |
| MatchStart | 44 | `MatchStartData` (empty) | — |
| MatchScoreUpdate | 47 | `MatchScoreUpdateData` | — |
| MatchComplete | 49 | `MatchCompleteData` (empty) | — |
| MatchChangeMods | 51 | `MatchChangeModsData` | — |
| MatchLoadComplete | 52 | `MatchLoadCompleteData` (empty) | — |
| MatchNoBeatmap | 54 | `MatchNoBeatmapData` (empty) | — |
| MatchNotReady | 55 | `MatchNotReadyData` (empty) | — |
| MatchFailed | 56 | `MatchFailedData` (empty) | — |
| MatchHasBeatmap | 59 | `MatchHasBeatmapData` (empty) | — |
| MatchSkipRequest | 60 | `MatchSkipRequestData` (empty) | — |
| MatchTransferHost | 70 | `MatchTransferHostData` | — |
| MatchChangeTeam | 77 | `MatchChangeTeamData` (empty) | — |
| MatchInvite | 87 | `MatchInviteData` | — |
| MatchChangePassword | 90 | `bancho.protocol.MultiplayerMatch` | — |
| FriendAdd | 73 | `FriendAddData` | — |
| FriendRemove | 74 | `FriendRemoveData` | — |
| ReceiveUpdates | 79 | `ReceiveUpdatesData` | ✓ |
| SetAwayMessage | 82 | `bancho.protocol.Message` | — |
| UserStatsRequest | 85 | `UserStatsRequestData` | ✓ |
| UserPresenceRequest | 97 | `UserPresenceRequestData` | — |
| UserPresenceRequestAll | 98 | `UserPresenceRequestAllData` | — |
| ToggleBlockNonFriendDms | 99 | `ToggleBlockNonFriendDmsData` | — |
| TournamentMatchInfoRequest | 93 | `TournamentMatchInfoRequestData` (empty) | — |
| TournamentJoinMatchChannel | 108 | `TournamentJoinMatchChannelData` (empty) | — |
| TournamentLeaveMatchChannel | 109 | `TournamentLeaveMatchChannelData` (empty) | — |

### Command Dispatcher (`bancho/command/`)

In-chat command parsing and dispatch.

- **CommandSet.lua** — Class for grouped subcommands (e.g. `mp_*`). Each set has a `prefix`, optional `doc`, and a `commands` array.
- **CommandDispatcher.lua** — Parses `!command args` or `/command args` from chat messages. Supports flat commands, subcommand sets, privilege gating, hidden commands, and help text generation.
- **init.lua** — Registers the `help` command and the `mp_*` command set (`mp start`, `mp abort`, `mp map`, `mp host`, `mp mods`, `mp freemods`, `mp invite`).

### Configuration (`bancho/config/`)

Server configuration via `bancho.config.BanchoConfig` class. Follows the same pattern as `sphere.persistence.ConfigModel`: defaults defined in code, deep-merged with user overrides from a config file.

- **BanchoConfig.lua** — Config class with `new(overrides)` constructor and `merge(base, overrides)` static method. Deep-merges overrides into `BanchoConfig.defaults`. All fields have sensible defaults.
- **config.example.lua** — Documented example with all available fields. Copy to `config.lua` to get started.
- **config.lua** — Gitignored production config. Returns `BanchoConfig:new({...})` with production overrides.

**Config fields:**
- `domain` — Server domain (e.g. "rizu.su")
- `bot_name`, `bot_id` — Bot player identity
- `db_path` — SQLite database file path
- `mirror_search_endpoint`, `mirror_download_endpoint` — Beatmap mirror URLs
- `beatmaps_path`, `replays_path`, `screenshots_path` — File storage directories
- `max_matches` — Maximum concurrent multiplayer rooms
- `allow_registration` — Allow in-game registration
- `disallow_old_clients` — Reject outdated osu! clients
- `disallowed_names`, `disallowed_passwords` — Registration blocks
- `command_prefix` — In-game command prefix character
- `menu_icon_url`, `menu_onclick_url` — Main menu icon
- `seasonal_backgrounds` — Seasonal background configuration
- `cached_accuracies` — Accuracy percentages for /np PP pre-calculation
- `channels` — Default channel definitions

**Loading:** `BanchoServer:new()` loads `bancho/config.lua` automatically. Runtime overrides can be passed: `BanchoServer({ domain = "override.com" })`.

### Server State (`bancho/server/`)

- **BanchoServer.lua** — Central server state holding `PlayerCollection`, `MatchCollection`, `ChannelCollection`, `PacketRouter`, `CommandDispatcher`, and repository references. Provides shared state for all HTTP resources and packet handlers. Defines repository interfaces (`IUserRepo`, `IScoreRepo`, `IBeatmapRepo`, etc.) that can be backed by stubs (testing) or real database adapters (production). Configuration loaded from `bancho/config.lua` via `BanchoConfig`.

### HTTP Resources (`bancho/http/`)

HTTP resource classes that integrate with the `sea/` web framework via domain-based routing.

- **BanchoProtocolResource.lua** — `POST /` (Bancho protocol: login + packet exchange), `GET /` (status page), `GET /online`, `GET /matches`. Login flow: protocol version → login reply → bancho privileges | SUPPORTER → welcome notification → channel info (auto-join channels except #lobby, broadcast to viewers) → channel info end → main menu icon → friends list → silence end (remaining seconds) → user presence + stats → broadcast to others → other players' presence + stats (restricted players hidden). Packet exchange: lookup by token → process packets → drain queue. Domain-restricted to `osu.*`, `c.*`, `ce.*`, `c4.*`, `c5.*`, `c6.*`.
- **OsuWebResource.lua** — All `/web/*` endpoints. Implemented: score submission (multipart parsing, decryption, checksum validation, score persistence), leaderboards (with user name resolution), friends, beatmap info (filename MD5 lookup), favourites, screenshots (multipart upload with image validation), ratings, comments, mail, seasonal backgrounds, connection checks. Domain-restricted to `osu.*`.
- **FileResource.lua** — `/ss/:id.:ext` (screenshots), `/d/:set_id` (beatmap downloads via redirect), `/web/maps/:filename` (.osu files). Domain-restricted to `osu.*`.
- **AccountResource.lua** — `POST /users` (in-game registration with validation), `POST /difficulty-rating` (redirect). Domain-restricted to `osu.*`.

### Stubs (`bancho/stub/`)

Test doubles for external dependencies: `BcryptHasher`, `Repo` (users/scores/beatmaps with `findBestScore`, `addScore`), `HttpClient`, `GeoLocator`, `PerformanceCalculator`.

### Database (`bancho/db/`)

SQLite-backed persistence layer using `aqua/rdb` ORM. Follows the same pattern as `sea.storage.server.ServerSqliteDatabase`.

- **BanchoDatabase.lua** — Database wrapper with `LjsqliteDatabase`, `TableOrm`, `Models` (auto-loaded from `bancho.db.models`), and `SqliteMigrator`. Default path: `bancho.db`. Supports WAL mode, foreign keys, and versioned migrations.
- **schema.sql** — Initial schema (v1) with tables: `users`, `stats`, `beatmaps`, `scores`, `friends`, `favourites`, `replays`.
- **models/*.lua** — Model options for each table (type conversions, boolean fields).
- **repos/init.lua** — Factory that creates all repository instances from shared `rdb.Models`.
- **repos/UserRepo.lua** — `findUser`, `findUserByName` (case-insensitive), `findUserByNameAndPassword`, `createUser`, `partialUpdate`, `findByEmail`, `findByToken`.
- **repos/ScoreRepo.lua** — `findScores`, `findBestScore`, `findScore`, `addScore`, `findTopScores`.
- **repos/BeatmapRepo.lua** — `findBeatmap`, `findBeatmapById`, `findBeatmapByFilename`, `addBeatmap`, `updateCounts`.
- **repos/FriendsRepo.lua** — `getFriends`, `addFriend`, `removeFriend`.
- **repos/FavouritesRepo.lua** — `getFavourites`, `addFavourite`, `removeFavourite`.
- **repos/StatsRepo.lua** — `getStats`, `updateStats`, `createAllModes`.
- **repos/ReplayRepo.lua** — `saveReplay`, `getReplay`.

### Beatmap Loading (`bancho/beatmap/`)

- **BeatmapLoader.lua** — Parses `.osu` files from `storages/charts/<md5>` and populates beatmap metadata. Falls back to osu.direct API when local file is missing. Computes star rating for osu!mania from parsed notes.

**Beatmap loading flow**:
1. `ScoreSubmitter:submit()` calls `beatmap_repo:findBeatmap(md5)`
2. If not found → `beatmap_loader:load(md5)` reads `.osu` file from `storages/charts/<md5>`
3. If file missing → fetches from `osu.direct/api/get_beatmaps?h=<md5>`
4. Loaded beatmap is cached in DB via `beatmap_repo:addBeatmap()`

**Metadata extraction from `.osu`**:
- `RawOsu:decode()` parses all sections (General, Metadata, Difficulty, TimingPoints, HitObjects)
- Extracts: id, set_id, artist, title, version, creator, mode, cs, od, ar, hp, bpm, total_length, max_combo
- Mania SR computed via `osu_starrate.Beatmap:calculateStarRate()`
- Status defaults to `RankedStatus.PENDING`

**Integration**: `BanchoServer:setupDatabase(path)` creates the database, opens it, and wires all repos automatically. Called from `sea/app/Resources.lua` at startup. Default path is `bancho.db`; pass `":memory:"` for in-memory testing.

### End-to-End Flow

**Registration → Login → Score Submission** is now wired end-to-end:

1. **Registration** (`POST /users`): Validates username/email/password → computes `md5(password)` → `bcrypt(md5)` → stores only `pw_bcrypt` in DB → creates stats rows for all 4 modes → returns "ok". Uses `sea.access.BcryptPasswordHasher` (wraps `bcrypt` FFI). `pw_md5` is **not stored** — it's only used as an intermediate to compute bcrypt.
2. **Login** (`POST /` Bancho protocol): Parses credentials → looks up user by name → verifies `bcrypt.verify(client_md5, pw_bcrypt)` → creates in-memory `Player` with token → sends login packet sequence → returns `cho-token` header.
3. **Score Submission** (`POST /web/osu-submit-modular.php`): Decrypts score (Rijndael-256 CBC) → validates checksum → looks up beatmap → calculates accuracy + PP → persists score + replay → updates stats → returns chart response.

**Beatmap Storage**: Beatmap metadata is loaded on-demand via `bancho.beatmap.BeatmapLoader`:
- **Local `.osu` files**: `storages/charts/<md5>` — parsed with `chart.format.osu.RawOsu` to extract all metadata
- **Star rating**: Computed from notes for osu!mania via `chart.scoring.osu_starrate`; other modes default to 0
- **API fallback**: `osu.direct/api/get_beatmaps?h=<md5>` — used when local file is missing
- **Caching**: Loaded beatmaps are cached in the SQLite `beatmaps` table for future lookups
- **Score submission**: `ScoreSubmitter:submit()` uses `beatmap_loader:load()` when DB lookup fails

### Tests

Every module has a corresponding `_test.lua` file covering core behavior.

---

## Complete Endpoint List

All endpoints below are HTTP-only. The Bancho protocol uses only POST `/` with token-based session management. Every other endpoint is a standard HTTP request from the osu! client.

### Bancho Protocol

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/` | Status page (browser) showing online players, matches, handled packets |
| `POST` | `/` | **Bancho protocol endpoint** — login (no `osu-token`) or packet exchange (with `osu-token`) |
| `GET` | `/online` | Debug page listing online players and bots |
| `GET` | `/matches` | Debug page listing active multiplayer matches |

### In-Game Web API (`/web/`)

These endpoints are called directly by the osu! client during normal gameplay.

| Method | Path | Description |
| :--- | :--- | :--- |
| `POST` | `/web/osu-submit-modular.php` | **Score submission** — multipart POST with encrypted score data, replay file, IV, password, osu version, client hash, unique IDs. Decrypts score, verifies checksums, calculates PP/accuracy, stores score, updates stats, returns submission charts |
| `POST` | `/web/osu-submit-modular-selector.php` | **Score submission (session variant)** — same as above but authenticated via `token` header instead of password |
| `GET` | `/web/osu-osz2-getscores.php` | **Leaderboard** — returns ranked status, beatmap metadata, personal best, and up to 50 scores in pipe-delimited format. Supports types: Top, Mods, Friends, Country, Local |
| `GET` | `/web/osu-getreplay.php` | Serve `.osr` replay files by score ID |
| `GET` | `/web/osu-getfriends.php` | Return newline-delimited friend user IDs |
| `POST` | `/web/osu-getbeatmapinfo.php` | Beatmap info lookup by filename or ID. Returns map ID, set ID, MD5, status, per-mode grades |
| `GET` | `/web/osu-search.php` | Beatmap search (proxies to osu! API mirror). Returns osu!Direct format |
| `GET` | `/web/osu-search-set.php` | Beatmap set detail lookup by set ID, beatmap ID, or checksum |
| `GET` | `/web/osu-getfavourites.php` | Return newline-delimited favourited set IDs |
| `GET` | `/web/osu-addfavourite.php` | Add beatmap set to favourites |
| `GET` | `/web/lastfm.php` | **Anti-cheat** — client sends hidden flags detecting modified clients (hq!osu, AQN). Returns empty or triggers restriction |
| `POST` | `/web/osu-screenshot.php` | Screenshot upload. Validates PNG/JPEG headers, stores file |
| `GET` | `/web/osu-rate.php` | Beatmap rating submission and average retrieval |
| `POST` | `/web/osu-comment.php` | Beatmap/replay comment get (action=get) and post (action=post) |
| `GET` | `/web/osu-markasread.php` | Mark mail conversation as read |
| `GET` | `/web/osu-getseasonal.php` | Return seasonal background configuration (JSON) |
| `GET` | `/web/bancho_connect.php` | Client connection check (called before login) |
| `GET` | `/web/check-updates.php` | Client update check |

### File Serving

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/ss/{id}.{ext}` | Serve screenshot files (jpg/jpeg/png) |
| `GET` | `/d/{set_id}` | Redirect to beatmap download (`.osz2`) from mirror |
| `GET` | `/web/maps/{filename}` | Serve updated `.osu` files |

### Account Management

| Method | Path | Description |
| :--- | :--- | :--- |
| `POST` | `/users` | **In-game registration** — validates username, email, password, creates user + stats rows |
| `POST` | `/difficulty-rating` | Redirect to osu.ppy.sh |

### Out Of Scope

The following endpoint groups exist in bancho.py but are **not needed** for our implementation:

- **Developer API v1** (`/api/v1/*`) — 16 public endpoints for external integrations (player search, stats, leaderboards, PP calculation). Not needed since we don't have a separate web frontend consuming these.
- **Developer API v2** (`/api/v2/*`) — REST API for a web frontend (clans, maps, players, scores). Not needed for the same reason.
- **Redirects** (`/beatmapsets/*`, `/beatmaps/*`, etc.) — Conditional redirects to `osu.ppy.sh` for browser navigation. Irrelevant for an in-game server.

### Unhandled Endpoints

These endpoints exist on official osu! servers but are not implemented by bancho.py:

- `POST /web/osu-error.php` — Client error reporting
- `POST /web/osu-session.php` — Session management
- `POST /web/osu-osz2-bmsubmit-post.php` — Beatmap submission
- `POST /web/osu-osz2-bmsubmit-upload.php` — Beatmap file upload
- `GET /web/osu-osz2-bmsubmit-getid.php` — Beatmap submission ID
- `GET /web/osu-get-beatmap-topic.php` | Forum topic for a beatmap set |

---

## What Is Needed For A Fully Working osu! Server

The code above covers the protocol layer, domain models, and business logic in isolation. To become a production-ready osu! server, the following pieces are still needed:

### 1. HTTP Server (Transport Layer)

The Bancho protocol uses **only HTTP POST** for transport — no raw TCP, no WebSocket. Every client→server message is its own HTTP POST, and the server's reply packets are batched into the response body.

- **POST `/` (Bancho)** — On login (no `osu-token` header): body is `username\npassword_md5\nclient_info\n`, response is `cho-token` header + binary packet body. On subsequent requests: validates `osu-token` header, processes incoming binary packets, drains the player's queued outgoing packets as the response body.
- **Integration with LÖVE's networking** — Since this runs inside the LÖVE game client, the server needs to bridge between LÖVE's socket API and the Bancho protocol. The key architectural decision: whether the bancho module runs as a standalone Lua HTTP server (using LuaSocket or similar) or as a component within the game's existing network layer.

### 2. Real Database Backend

**DONE** — SQLite backend implemented in `bancho/db/` using `aqua/rdb` ORM.

Implemented tables: `users`, `stats`, `beatmaps`, `scores`, `friends`, `favourites`, `replays`.
All repositories (`UserRepo`, `ScoreRepo`, `BeatmapRepo`, `FriendsRepo`, `FavouritesRepo`, `StatsRepo`, `ReplayRepo`) are wired through `BanchoServer:setupDatabase()`.

**Remaining tables** (not yet needed):
- **Mail table** — In-game mail system.
- **Achievements tables** — Server achievement definitions and per-user unlocked achievements.
- **Ratings table** — Per-user beatmap ratings.
- **Logs table** — In-game login logs, moderation logs, chat logs.
- **Clans tables** — Clan definitions, clan members, clan tags.

### 3. Real Rijndael-256 Implementation

**DONE** — `bancho/crypto/Rijndael.lua` implements AES-256-CBC with PKCS7 padding via OpenSSL FFI. `ScoreCrypto` delegates to it.

- **Rijndael-256 CBC** with PKCS7 padding for decrypting the `score` form parameter.
- **Key derivation**: `"osu!-scoreburgr---------{osu_version}"` (32 bytes).
- **IV**: Provided by the client in the `iv` form parameter (base64).
- Uses LuaJIT FFI to call OpenSSL `EVP_aes_256_cbc` directly.

### 4. Web API Endpoints

The osu! client makes HTTP requests to several endpoints beyond the Bancho protocol. **All endpoints are now implemented as `IResource` classes in `bancho/http/`** and registered with domain-based routing. The following remain as stubs or partial implementations:

- **`POST /web/osu-submit-modular.php`** — Score submission: multipart parsing, score decryption (Rijndael-256 CBC), checksum verification, PP calculation (mania), chart response generation, score persistence, stats update.
- **`POST /web/osu-submit-modular-selector.php`** — Token-authenticated variant. Same needs as above.
- **`GET /web/osu-osz2-getscores.php`** — Leaderboard skeleton exists. Returns basic structure; needs: proper score lookup, personal best calculation, leaderboard type filtering.
- **`GET /web/osu-getreplay.php`** — Replay serving skeleton. Needs: replay repo integration.
- **`GET /web/osu-getfriends.php`** — Friends list skeleton. Needs: friends repo integration.
- **`POST /web/osu-getbeatmapinfo.php`** — Beatmap info stub. Needs: filename lookup, grade computation.
- **`GET /web/osu-search.php`** — Search proxy stub. Needs: mirror integration.
- **`GET /web/osu-search-set.php`** — Set detail stub. Needs: database lookup.
- **`GET /web/osu-getfavourites.php`** — Favourites stub. Needs: favourites repo.
- **`GET /web/osu-addfavourite.php`** — Add favourite stub. Needs: favourites repo.
- **`GET /web/lastfm.php`** — Anti-cheat skeleton. Basic flag parsing exists.
- **`POST /web/osu-screenshot.php`** — Screenshot upload stub. Needs: multipart parsing, file validation, storage.
- **`GET /web/osu-rate.php`** — Rating stub. Needs: ratings repo.

Additionally:
- **`POST /users`** — In-game registration. Full implementation with validation exists.
- **`GET /ss/:id.:ext`** — Screenshot serving. Full implementation exists.
- **`GET /d/:set_id`** — Download redirect. Redirects to osu.ppy.sh.
- **`GET /web/maps/:filename`** — .osu file serving. Full implementation exists.

### 5. Performance Calculation (PP/SR)

**osu!mania PP: DONE** — `Score:calculatePP(beatmap)` uses `chart/scoring/osu_pp.lua` to compute PP from accuracy, star rating, note count, and OD. Stores result in `score.pp` and `score.sr`.

**Other modes (osu!std, taiko, catch): NOT IMPLEMENTED** — `calculatePP` returns 0 for non-mania modes.

- **Star Rating (SR)** — Stored on `Beatmap.diff`. For mania, can be computed from `.osu` notes via `chart/scoring/osu_starrate.lua`.
- **Performance Points (PP)** — `chart/scoring/osu_pp.lua` implements the mania PP formula. `Score:calculatePP(beatmap)` calls it during submission.
- **Options for other modes**: (a) FFI binding to `baton` C++ library, (b) HTTP call to a PP calculation microservice, (c) pure-Lua port of the algorithm.

### 6. Beatmap File Management

- **`.osu` file storage** — Beatmap files need to be stored on disk (typically in `.data/osz2/` or similar) for replay playback and PP calculation.
- **`.osz`/`.osz2` archive handling** — Download and extract beatmap sets from the osu! API or manual upload.
- **Beatmap mirror integration** — Sync beatmap metadata from `https://osu.ppy.sh/` or a mirror (like `quasibit` or `flyingshots`). The `MIRROR_SEARCH_ENDPOINT` setting controls this.
- **File serving** — Serve `.osz2` files to clients for download during multiplayer matches.

### 7. Packet Handler Coverage

bancho.py registers **46 handlers** total. We have implemented **all 46**.

**Full coverage** — all `@register(ClientPackets.*)` handlers from bancho.py are implemented.

**Low-priority gaps** (non-blocking, documented in handler source):
- **SendPrivateMessage** — Online-to-online only. Missing: mail system for offline messages, command dispatcher integration with bot, /np PP calculation.
- **UserStatsRequest/UserPresenceRequest** — Uses `country_code = 0`, `longitude = 0`, `latitude = 0` (geo not implemented).
- **Tournament handlers** (3) — Stubs. Tournament system not implemented.

**Not registered by bancho.py** (defined in `ClientPackets` but no `@register`):
- `ERROR_REPORT` (20), `BEATMAP_INFO_REQUEST` (68), `IRC_ONLY` (84) — not handled by bancho.py

**Remaining work on existing handlers:**
- **SendPublicMessage** — Command dispatcher wired. `!command` messages are dispatched; responses sent to channel.
- **SendPrivateMessage** — Command dispatcher wired for bot PMs. `!command` to bot dispatches and responds.
- **Spectator system** — `Player.lua` has `spectating`/`spectators` fields; handlers use them. Fellow-spectator notifications are implemented.
- **Multiplayer relay** — All match packets now handled: `MATCH_LOAD_COMPLETE`, `MATCH_SKIP`, `MATCH_FAIL`, `MATCH_NO_BEATMAP`, `MATCH_HAS_BEATMAP`, etc.

### 8. Anti-Cheat System

- **Score checksum validation** — **DONE** — `Score:computeOnlineChecksum()` computes MD5 of the chickenmcnuggets salted string and compares against client-provided checksum. Rejects tampered scores.
- **Client hash verification** — On login, store and verify client file hashes (path MD5, adapters, uninstall, disk signature).
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

**DONE** — `bancho.config.BanchoConfig` class with defaults, `bancho/config.example.lua`, and gitignored `bancho/config.lua`.

**Remaining:**
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
- **Multi-region endpoint support** — `SWITCH_SERVER` packet for failover between server instances.

---

## ADR: DB-Only Persisted User Fields

### Decision

Persisted user data remains DB-owned and is not duplicated into shared Bancho session objects.

### Why

bancho.py often keeps more user/profile state live on the in-memory player object. In this Lua port, shared session objects are also serialized through shared dicts for cross-worker visibility. Mirroring DB-backed user fields into `Player` would create two sources of truth:

- the SQLite row (`users`, `friends`, related repos)
- the shared-session `Player` snapshot in memory/shared dicts

That duplication makes cross-worker bugs easier to introduce and harder to reason about.

### Consequences

`bancho.model.Player` should contain session/runtime state only, for example:

- login token
- online status
- current action/map/mods/mode
- silence state for the active session
- spectating relationships
- multiplayer membership
- per-request packet queue

The following stay DB-owned and must be queried from repos when needed instead of cached in `Player`:

- friends / friend relationships
- PM privacy (`pm_private`)
- away message (`away_msg`)
- presence filter (`pres_filter`)
- UTC offset and other profile/session-preference fields stored in `users`

### Implementation Rule

When a handler needs persisted user data, prefer repo lookups at the point of use over copying that data into shared player serialization. This differs from bancho.py in some places, but keeps a single source of truth in this port.

## Shared Dict Implementation

**DONE** — `PlayerCollection`, `MatchCollection`, `ChannelCollection` accept optional `ISharedDict`.
`BanchoServer:new(shared_memory)` injects dict backends. `BanchoProtocolResource` uses `drain_packets`.
19 integration tests in `bancho/model/SharedDictCollection_test.lua`.

### Remaining

- **Persistent state across server restarts** — shared dicts are volatile; need periodic DB sync
- **Background task integration** — ghost disconnect, donor expiry (separate concern)
- **`lua_code_cache = "on"`** — production `nginx_config.lua` still has `"off"`; switch when ready

### Implementation Details

OpenResty runs N worker processes (one per CPU core by default). Each worker has its own Lua state and Lua module cache. With `lua_code_cache = "off"` (current dev config), modules are reloaded every request — meaning `BanchoServer` is recreated fresh on every request and all in-memory state is lost. Even with `lua_code_cache = "on"`, state is isolated per worker — a player logged in via worker 1 is invisible to worker 2.

### Problem

OpenResty runs N worker processes (one per CPU core by default). Each worker has its own Lua state and Lua module cache. With `lua_code_cache = "off"` (current dev config), modules are reloaded every request — meaning `BanchoServer` is recreated fresh on every request and all in-memory state is lost. Even with `lua_code_cache = "on"`, state is isolated per worker — a player logged in via worker 1 is invisible to worker 2.

**Current in-memory state lost between requests/workers:**

| Collection | Location | Contents | Impact if lost |
|---|---|---|---|
| `PlayerCollection` | `server.players` | Online players by token, ID, safe_name | Login→packet exchange broken |
| `MatchCollection` | `server.matches` | Up to 64 active multiplayer rooms | All match state lost |
| `ChannelCollection` | `server.channels` | Chat channels + player membership | Chat broken |
| `Player._packet_queue` | per-player | Outgoing binary packets | Responses never sent |
| `Player.status` | per-player | Action, map, mods, mode | Presence broken |
| `Player.spectating` / `.spectators` | per-player | Cross-player references | Spectating broken |
| `Match.slots[16]` | per-match | Player refs, status, team, mods | Match relay broken |
| `Channel.players` | per-channel | Player ID set | Membership broken |

### Existing Infrastructure

The project already has the solution pattern:

```
SharedMemory:get("name")
  → NginxSharedDict(ngx.shared.name)    in production (OpenResty)
  → FakeSharedDict()                     in tests (LuaJIT)
```

Already declared in `nginx_config.lua`:
```lua
shared_dicts = {
    players = "1m",
    mp_rooms = "1m",
    mp_room_users = "1m",
}
```

### Design

**New shared dict declarations** (in `nginx_config.lua`):
```lua
shared_dicts = {
    players = "1m",
    mp_rooms = "1m",
    mp_room_users = "1m",
    bancho_players = "10m",   -- serialized Player data
    bancho_matches = "5m",    -- serialized Match data
    bancho_channels = "1m",   -- serialized Channel data
}
```

**Key naming convention:**
- `"p:<token>"` → Player data (lookup by token for packet exchange)
- `"pid:<id>"` → Player data (lookup by ID for broadcasts)
- `"m:<id>"` → Match data
- `"c:<name>"` → Channel data
- `"pq:<token>"` → Packet queue (using dict list ops)

**Serialization:** `ISharedDict` stores JSON-serializable values. Domain objects are converted to flat data tables (no methods, no live cross-references) before storage. References are resolved by ID on access.

Player data shape stored in dict:
```lua
{
    id = 123,
    name = "Player",
    token = "abc-def-ghi",
    priv = 1,
    restricted = false,
    silenced = false,
    silence_end = 0,
    utc_offset = 0,
    pm_private = false,
    stealth = false,
    in_lobby = false,
    away_msg = nil,
    pres_filter = 0,
    spectating_id = nil,        -- player ID, not reference
    spectators = { 456, 789 },  -- player IDs, not references
    match_id = nil,             -- match ID, not reference
    blocks = {},
    friends = {},
    status = { action = 0, info_text = "", map_md5 = "", mods = 0, mode = 0, map_id = 0 },
    stats = { [0] = { tscore = 0, rscore = 0, pp = 0, acc = 0, plays = 0, playtime = 0, max_combo = 0, rank = 0, grades = {} }, ... },
}
```

**Collection rewrite:** `PlayerCollection`, `MatchCollection`, `ChannelCollection` accept an `ISharedDict` and delegate storage. API surface (`get`, `add`, `remove`, `all`) stays identical — callers are unaware of the backend.

**Injection:** `BanchoServer:new(shared_memory)` receives `SharedMemory` from `sea.app.App`. Collections are constructed with `shared_memory:get("bancho_players")`, etc.

### Implementation Steps

**Step 1: Serialization layer** (`bancho/model/PlayerData.lua`, `MatchData.lua`, `ChannelData.lua`)
- Define flat data shapes for each entity
- `Player:toData()` / `Player.fromData(data, collection)` conversion methods
- `Match:toData()` / `Match.fromData(data, collection)` conversion methods
- `Channel:toData()` / `Channel.fromData(data, collection)` conversion methods
- Cross-references stored as IDs; resolved via collection lookup on `fromData()`

**Step 2: SharedDict-backed collections** (`bancho/model/PlayerCollection.lua` etc.)
- Accept optional `ISharedDict` in constructor
- When dict is present: all CRUD goes through dict (JSON serialize/deserialize)
- When dict is absent: fall back to in-memory tables (existing behavior, for tests)
- `PlayerCollection:get(token)` → dict `get("p:<token>")` or dict `get("pid:<id>")`
- `PlayerCollection:add(player)` → dict `set("p:<token>", data)` + dict `set("pid:<id>", data)`
- `PlayerCollection:remove(player)` → dict `delete("p:<token>")` + dict `delete("pid:<id>")`
- `PlayerCollection:all()` → iterate dict keys, deserialize
- `PlayerCollection:enqueue(data, immune)` → for each player, dict `rpush("pq:<token>", data)`
- Packet drain → `BanchoProtocolResource:handlePackets()` uses dict `lpop("pq:<token>")` in loop

**Step 3: BanchoServer wiring**
- `BanchoServer:new(config, shared_memory)` — accept SharedMemory parameter
- Create collections with dict backends: `PlayerCollection(shared_memory:get("bancho_players"))`
- `sea/app/Resources.lua` passes `self.shared_memory` to `BanchoServer()`
- Config file adds `shared_dicts` section for dict size overrides

**Step 4: Integration tests**
- Verify login → packet exchange → logout flow with `FakeSharedDict`
- Verify two separate `BanchoServer` instances sharing the same dict see each other's players
- Verify match creation/join/relay with shared state
- Verify channel join/leave/message with shared state
- Verify packet queue accumulation and drain

**Step 5: Production config**
- `nginx_config.lua` declares `bancho_players`, `bancho_matches`, `bancho_channels`
- `bancho/config.lua` adds `shared_dicts` section for size tuning
- `lua_code_cache = "on"` in production `nginx_config.lua`

### Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Dict memory exhaustion | Monitor `free_space()`, implement eviction of stale players |n|---|---|
| Concurrent access to same key | OpenResty shared dicts are thread-safe; use `replace()` for atomic updates |
| Large packet queues | Limit queue size per player; drop oldest packets if limit exceeded |
| Serialization/deserialization cost | Profile; batch operations; cache deserialized objects per-request |
| Cross-reference consistency | Resolve references at read time, not write time; accept eventual consistency |

### Out Of Scope (for now)

- Persistent state across server restarts (shared dicts are volatile)
- Cross-server state sync (single OpenResty instance)
- Background task integration (ghost disconnect, donor expiry) — separate concern

---

## Architecture Notes

### Module Organization

```
bancho/
  client/       — Bancho protocol client for e2e testing and rizu integration (see bancho/client/spec.md)
  config/       — Configuration class (BanchoConfig) + example
  protocol/     — Binary protocol (packets, serialization)
  model/        — Domain objects (Player, Match, Score, etc.)
  auth/         — Authentication (login parsing, validation)
  score/        — Score submission processing
  multiplayer/  — Match lifecycle management
  chat/         — Chat and channel management
  crypto/       — Encryption/decryption
  constants/    — Enums and bitmasks
  handler/      — Packet router + handler classes (IPacketHandler, PacketRouter, 46 handlers)
  command/      — Command dispatcher + command set classes
  server/       — Central server state (BanchoServer)
  http/         — HTTP resource classes for sea/ integration
  stub/         — Test doubles for external dependencies
```

**Config files:**
- `bancho/config.example.lua` — Documented example (committed)
- `bancho/config.lua` — Production overrides (gitignored)

### Design Principles

- **Stub-driven**: External dependencies (database, crypto, HTTP, geolocation, PP calculation) are abstracted behind stubs. This allows full unit testing without infrastructure.
- **Packet queue model**: Each player has an internal packet queue. Managers enqueue packets; the transport layer drains them on each client request.
- **Shared dict collections**: `PlayerCollection`, `MatchCollection`, `ChannelCollection` delegate to `ISharedDict` in production (OpenResty `ngx.shared.DICT`) and fall back to in-memory tables in tests (`FakeSharedDict`). All cross-references stored as IDs and resolved on access. See [Shared Dict Implementation Plan](#shared-dict-implementation-plan).
- **LuaJIT FFI**: Used for binary operations (float conversion, LEB128). Should also be used for crypto (Rijndael-256) and potentially PP calculation (baton binding).
- **Class inheritance**: All packet handlers inherit `IPacketHandler` via `IPacketHandler + {}`. Uniform API: `parse(reader, bodyLen)` reads exactly `bodyLen` bytes, `handle(server, player, data)` executes business logic. Each handler defines a local `HandlerData` type used as the return type of `parse` and parameter type of `handle`.

### HTTP Integration With sea/

Bancho HTTP endpoints are integrated into the `sea/` web framework as `IResource` classes registered in `sea/app/Resources.lua`. The router supports **domain-based routing** so different `Host` headers get different handlers:

```
Reverse Proxy (nginx)
  └── example.com:443 → localhost:8091 (sea app, all domains)
       ├── Host: example.com → website resources (index, auth, users, etc.)
       ├── Host: osu.{domain} → bancho /web/* endpoints + Bancho protocol
       ├── Host: c/c4/c5/c6.{domain} → Bancho protocol only
       └── Host: b.{domain} → beatmap files (redirect to osu!)
```

**Domain-based routing** works as follows:
- Each `IResource` can declare a `domains` field (string array of patterns)
- Patterns support `*` as a wildcard (e.g., `"c.*"` matches `"c.example.com"`, `"c.other.net"`)
- Resources with domain restrictions match only when the `Host` header matches
- Resources without domain restrictions match all hosts (backward compatible)
- The router checks domain-restricted routes first, then falls back to unrestricted routes

**Configuration**: `nginx_config.lua` has `proxied = true` to read `X-Real-IP` from the reverse proxy and `client_max_body_size = "20M"` for score submissions with replay files.

### Integration With The Game Client

This module is designed to run inside the LÖVE-based game client. The key integration points are:

1. **Networking**: The transport layer needs to connect to LÖVE's `love.socket` or the project's existing network infrastructure.
2. **Shared memory / IPC**: If the server runs in a separate thread or process, inter-process communication is needed for state sharing.
3. **Asset access**: Beatmap files and replay files need to be accessible from the game's file system.
