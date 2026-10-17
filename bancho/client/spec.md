# Bancho Client

## Goal
A lightweight bancho protocol client for end-to-end testing, interoperability verification, and future rizu integration.

## User Experience
- Developers can run automated e2e tests against the local server without manual osu! client setup
- The client can connect to any bancho-compatible server (bancho.py, osu! servers, our server)
- Test scripts can simulate player actions: login, chat, match join/leave, score submission, spectating
- Eventually serves as the networking layer for rizu's multiplayer features

## Architecture

### Design Principles
- **Protocol-agnostic transport**: The client speaks the bancho binary protocol but works over HTTP (current) or TCP (future)
- **Stub-driven testing**: All external dependencies (HTTP, crypto, file I/O) are abstracted behind interfaces
- **Event-driven**: The client exposes events for packet reception, connection state changes, and errors
- **Lightweight**: No GUI dependencies - pure Lua that works in both LÖVE and CLI environments

### Module Organization
```
bancho/client/
  BanchoClient.lua        -- Main client class
  ClientConfig.lua        -- Configuration (server URL, credentials, timeouts)
  PacketQueue.lua         -- Outgoing packet queue with priority
  ConnectionState.lua     -- Connection state machine (disconnected, connecting, connected, reconnecting)
  transport/
    HttpTransport.lua     -- HTTP POST transport (current bancho protocol)
    TcpTransport.lua      -- TCP transport (future, for direct socket connections)
  handler/
    ClientPacketRouter.lua -- Route incoming packets to handlers
    IClientPacketHandler.lua -- Interface for packet handlers
    LoginHandler.lua      -- Login flow handler
    MatchHandler.lua      -- Match event handler
    ChatHandler.lua       -- Chat message handler
    ScoreHandler.lua      -- Score submission handler
  test/
    E2ETestRunner.lua     -- Automated test runner
    TestScenarios.lua     -- Predefined test scenarios
    FakeServer.lua        -- Mock server for unit testing
```

### Core Components

#### BanchoClient
Main entry point. Manages connection lifecycle, packet routing, and state.

```lua
local client = BanchoClient(ClientConfig {
    host = "localhost",
    port = 8091,
    username = "test_user",
    password = "test_password",
    timeout = 5000,
    max_retries = 3,
})

client:on("connected", function() print("Connected!") end)
client:on("disconnected", function(reason) print("Disconnected:", reason) end)
client:on("chat_message", function(sender, message) print(sender .. ": " .. message) end)

client:connect()
client:send_chat("#general", "Hello, world!")
client:join_match(1, "")
client:submit_score(score_data)
client:disconnect()
```

#### Transport Layer
Abstracts the underlying network protocol. Currently HTTP POST, with TCP support planned.

- **HttpTransport**: Implements the current bancho protocol over HTTP
  - POST / for login (no osu-token header)
  - POST / with osu-token header for packet exchange
  - Handles binary packet serialization/deserialization
  - Manages connection tokens and reconnection

- **TcpTransport** (future): Direct TCP socket connection
  - For servers that support direct socket connections
  - Lower latency, persistent connection
  - Needed for rizu integration

#### Packet Handling
Mirrors the server's packet handling but from the client perspective.

- **ClientPacketRouter**: Routes incoming binary packets to appropriate handlers
- **IClientPacketHandler**: Interface for packet-specific logic
- **LoginHandler**: Manages login flow, token storage, reconnection
- **MatchHandler**: Handles match events, state synchronization
- **ChatHandler**: Processes chat messages, channel events
- **ScoreHandler**: Manages score submission, result processing

#### Connection State Machine
```
disconnected -> connecting -> connected -> reconnecting -> connected
                    |              |              |
                    v              v              v
                error          error          error
```

States:
- **disconnected**: Initial state, no active connection
- **connecting**: Attempting to establish connection
- **connected**: Active connection, can send/receive packets
- **reconnecting**: Connection lost, attempting to re-establish
- **error**: Fatal error, manual intervention needed

### Testing Strategy

#### End-to-End Tests
Automated tests that verify the complete client-server interaction.

Test scenarios:
1. **Login flow**: Successful login, invalid credentials, already logged in
2. **Chat**: Send/receive messages, channel join/leave, private messages
3. **Match**: Create/join/leave matches, ready up, start match, skip map
4. **Score submission**: Submit score, verify ranking update
5. **Spectating**: Start/stop spectating, spectator notifications
6. **Reconnection**: Server restart, network interruption, token validation
7. **Concurrent players**: Multiple clients, cross-player interactions

#### Integration with Existing Tests
- Use `FakeSharedDict` for isolated test environments
- Test runner spawns server and client processes
- Verify state consistency across worker boundaries
- Performance benchmarks for packet throughput and latency

#### Test Against External Servers
- **bancho.py**: Verify interoperability with reference implementation
- **osu! servers**: Verify protocol compatibility (for development/testing only)
- Custom test servers for specific scenarios

### Future Integration with Rizu
The client will eventually serve as the networking layer for rizu's multiplayer features.

Integration points:
1. **Connection management**: Rizu manages the client lifecycle
2. **Event routing**: Client events drive rizu's UI and gameplay state
3. **Packet serialization**: Shared protocol definitions between client and server
4. **Configuration**: Server selection, authentication, preferences

Migration path:
1. Standalone client for testing (current phase)
2. Shared protocol definitions between client and server
3. Rizu integration with event-driven architecture
4. Full multiplayer support in rizu

## Implementation Status

### Phase 1: Core Client ✅ DONE
- [x] `BanchoClient.lua` with basic connection lifecycle
- [x] `ClientConfig.lua` with configuration management
- [x] `HttpTransport.lua` for HTTP POST communication
- [x] Basic packet serialization/deserialization
- [x] Login flow implementation
- [x] Unit tests for core components (59 tests)

### Phase 2: Protocol Support ✅ DONE
- [x] All client packet builders (chat, match, spectating, friends, status)
- [x] Match management (ready, lock, start, skip, transfer host, mods, team, password)
- [x] Presence and stats requests
- [x] Unit tests for all packet types
- [x] Packet parsing tests

### Phase 3: Testing Infrastructure (in progress)
- [x] Unit tests for packet building and parsing
- [ ] E2E test runner with mock server
- [ ] Performance benchmarks
- [ ] CI/CD pipeline

### Phase 4: Rizu Integration
- [ ] Shared protocol definitions
- [ ] Event-driven architecture for rizu
- [ ] UI integration for multiplayer features
- [ ] Configuration management
- [ ] Performance optimization for gameplay

### Phase 2: Protocol Support
- [ ] `ClientPacketRouter.lua` for incoming packet routing
- [ ] Packet handlers for chat, match, score submission
- [ ] Connection state machine with reconnection logic
- [ ] Packet queue with priority handling
- [ ] Integration tests for protocol compliance

### Phase 3: Testing Infrastructure
- [ ] `E2ETestRunner.lua` for automated testing
- [ ] Test scenarios for all major features
- [ ] Performance benchmarks
- [ ] Integration with existing test suite
- [ ] CI/CD pipeline for automated e2e tests

### Phase 4: Rizu Integration
- [ ] Shared protocol definitions
- [ ] Event-driven architecture for rizu
- [ ] UI integration for multiplayer features
- [ ] Configuration management
- [ ] Performance optimization for gameplay

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Protocol changes break compatibility | Version negotiation, protocol abstraction layer |
| HTTP overhead for real-time gameplay | TCP transport option, packet batching |
| Test flakiness due to timing | Deterministic test scenarios, retry logic |
| Security concerns with test credentials | Isolated test environments, credential rotation |
| Performance bottlenecks in packet handling | Profiling, optimization, async processing |

## Out of Scope
- Full osu! client replacement (this is a testing/development tool)
- Game rendering or audio processing
- User interface (CLI only for now)
- Anti-cheat bypass or modification
- Production deployment (development/testing only)
