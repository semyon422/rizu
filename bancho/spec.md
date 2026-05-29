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

### Server State (`bancho/server/`)

- **BanchoServer.lua** — Central server state holding `PlayerCollection`, `MatchCollection`, `ChannelCollection`, `PacketRouter`, `CommandDispatcher`, and repository references. Provides shared state for all HTTP resources and packet handlers. Defines repository interfaces (`IUserRepo`, `IScoreRepo`, `IBeatmapRepo`, etc.) that can be backed by stubs (testing) or real database adapters (production).

### HTTP Resources (`bancho/http/`)

HTTP resource classes that integrate with the `sea/` web framework via domain-based routing.

- **BanchoProtocolResource.lua** — `POST /` (Bancho protocol: login + packet exchange), `GET /` (status page), `GET /online`, `GET /matches`. Login flow: protocol version → login reply → bancho privileges | SUPPORTER → welcome notification → channel info (auto-join channels except #lobby, broadcast to viewers) → channel info end → main menu icon → friends list → silence end (remaining seconds) → user presence + stats → broadcast to others → other players' presence + stats (restricted players hidden). Packet exchange: lookup by token → process packets → drain queue. Domain-restricted to `osu.*`, `c.*`, `ce.*`, `c4.*`, `c5.*`, `c6.*`.
- **OsuWebResource.lua** — All `/web/*` endpoints. Implemented: score submission (multipart parsing, decryption, checksum validation, score persistence), leaderboards (with user name resolution), friends, beatmap info (filename MD5 lookup), favourites, screenshots (multipart upload with image validation), ratings, comments, mail, seasonal backgrounds, connection checks. Domain-restricted to `osu.*`.
- **FileResource.lua** — `/ss/:id.:ext` (screenshots), `/d/:set_id` (beatmap downloads via redirect), `/web/maps/:filename` (.osu files). Domain-restricted to `osu.*`.
- **AccountResource.lua** — `POST /users` (in-game registration with validation), `POST /difficulty-rating` (redirect). Domain-restricted to `osu.*`.

### Stubs (`bancho/stub/`)

Test doubles for external dependencies: `BcryptHasher`, `Repo` (users/scores/beatmaps with `findBestScore`, `addScore`), `HttpClient`, `GeoLocator`, `PerformanceCalculator`.

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
  handler/      — Packet router + handler classes (IPacketHandler, PacketRouter, 46 handlers)
  command/      — Command dispatcher + command set classes
  server/       — Central server state (BanchoServer)
  http/         — HTTP resource classes for sea/ integration
  stub/         — Test doubles for external dependencies
```

### Design Principles

- **Stub-driven**: External dependencies (database, crypto, HTTP, geolocation, PP calculation) are abstracted behind stubs. This allows full unit testing without infrastructure.
- **Packet queue model**: Each player has an internal packet queue. Managers enqueue packets; the transport layer drains them on each client request.
- **In-memory collections**: `PlayerCollection`, `MatchCollection`, `ChannelCollection` provide in-memory registries. For production, these would be backed by or synchronized with a database.
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
