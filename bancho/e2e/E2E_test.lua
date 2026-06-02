--- In-memory E2E tests for the Bancho protocol.
---
--- Uses real Request/Response objects backed by ExtendedStringSocket
--- to simulate HTTP without real networking.
--- Each request creates a fresh BanchoServer backed by shared FakeSharedDict
--- to simulate the multi-worker OpenResty model.

-- Stub ngx BEFORE requiring any other modules (BanchoProtocolResource uses ngx.log)
if not ngx then
	ngx = { log = function() end, WARN = 4, ERR = 3 }
end

local E2EContext = require("bancho.e2e.E2EContext")
local FakeHttpTransport = require("bancho.e2e.FakeHttpTransport")
local BanchoClient = require("bancho.client.BanchoClient")
local ClientConfig = require("bancho.client.ClientConfig")
local Binary = require("bancho.protocol.Binary")
local ServerPackets = require("bancho.protocol.ServerPackets")
local md5 = require("md5")

local test = {}

--- Helper: create an E2E client wrapper.
--- Wraps BanchoClient to use FakeHttpTransport instead of real HTTP.
--- Each method call creates a fresh server instance (simulating new worker).
local function create_e2e_client(ctx, username, password_md5)
	local config = ClientConfig {
		username = username,
		password_md5 = password_md5,
	}

	local client = BanchoClient(config)
	client.transport = FakeHttpTransport(config, function()
		return ctx:createResource()
	end)

	return client
end

--- Helper: find a packet by ID in a packet list.
---@param packets bancho.client.IncomingPacket[]
---@param id integer
---@return bancho.client.IncomingPacket?
local function find_packet(packets, id)
	for _, pkt in ipairs(packets) do
		if pkt.id == id then
			return pkt
		end
	end
	return nil
end

--- Helper: extract match ID from MATCH_JOIN_SUCCESS packet.
---@param packets bancho.client.IncomingPacket[]
---@return integer?
local function extract_match_id(packets)
	local pkt = find_packet(packets, ServerPackets.MATCH_JOIN_SUCCESS)
	if pkt then
		local ComplexTypes = require("bancho.protocol.ComplexTypes")
		local reader = require("bancho.protocol.PacketReader")(pkt.body)
		local match = ComplexTypes.readMatch(reader)
		return match.id
	end
	return nil
end

--- Helper: extract slot_statuses from UPDATE_MATCH packet.
---@param packets bancho.client.IncomingPacket[]
---@return integer[]?
local function extract_slot_statuses(packets)
	local pkt = find_packet(packets, ServerPackets.UPDATE_MATCH)
	if pkt then
		local ComplexTypes = require("bancho.protocol.ComplexTypes")
		local reader = require("bancho.protocol.PacketReader")(pkt.body)
		local match = ComplexTypes.readMatch(reader)
		return match.slot_statuses
	end
	return nil
end

--- Helper: extract message text from SEND_MESSAGE packet.
---@param packets bancho.client.IncomingPacket[]
---@return string?
local function extract_message(packets)
	local pkt = find_packet(packets, ServerPackets.SEND_MESSAGE)
	if pkt then
		local ComplexTypes = require("bancho.protocol.ComplexTypes")
		local reader = require("bancho.protocol.PacketReader")(pkt.body)
		local msg = ComplexTypes.readMessage(reader)
		return msg.text
	end
	return nil
end

-- ============================================================
-- Tests
-- ============================================================

--- Single player login flow.
function test.login(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	t:eq(user_id, 1)

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()

	t:eq(result.success, true)
	t:ne(result.user_id, -1)

	-- Check that login response contains expected packets
	local raw_packets, _ = client.transport:login_and_parse()
	t:ne(#raw_packets, 0)

	-- Should have USER_ID packet
	local user_pkt = find_packet(raw_packets, ServerPackets.USER_ID)
	t:ne(user_pkt, nil)
	t:eq(Binary.readI32(user_pkt.body, 1), user_id)

	ctx:close()
end

--- Login with wrong password fails.
function test.login_wrong_password(t)
	local ctx = E2EContext()
	ctx:createUser("TestUser", md5.sumhexa("correct"), 0)

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("wrong"))
	local result = client:login()

	t:eq(result.success, false)
	ctx:close()
end

--- Ping after login.
function test.ping(t)
	local ctx = E2EContext()
	ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)

	-- Ping returns no packets (server doesn't send PONG)
	local pkts, err = client:ping()
	t:eq(err, nil)
	t:eq(#pkts, 0)

	ctx:close()
end

--- Create and part a match.
function test.create_and_part_match(t)
	local ctx = E2EContext()
	ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)

	-- Create match
	local pkts, err = client:create_match("Test Match", "")
	t:eq(err, nil)
	t:ne(find_packet(pkts, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	local match_id = extract_match_id(pkts)
	t:ne(match_id, nil)

	-- Part match (sends UPDATE_MATCH, not DISPOSE_MATCH)
	pkts, err = client:part_match()
	t:eq(err, nil)
	t:ne(find_packet(pkts, ServerPackets.UPDATE_MATCH), nil)

	ctx:close()
end

--- Two-player match: create, join, ready, lock, part.
function test.two_player_match(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))

	-- Login both players
	local result_a = client_a:login()
	t:eq(result_a.success, true)
	t:eq(result_a.user_id, 1)

	local result_b = client_b:login()
	t:eq(result_b.success, true)
	t:eq(result_b.user_id, 2)

	-- Player A creates match
	local pkts_a, err = client_a:create_match("Duel", "")
	t:eq(err, nil)
	t:ne(find_packet(pkts_a, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)

	-- Player B joins match
	local pkts_b, err = client_b:join_match(match_id)
	t:eq(err, nil)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	-- Verify both players are in the match
	local join_data_b = require("bancho.protocol.ComplexTypes").readMatch(
		require("bancho.protocol.PacketReader")(
			find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS).body
		)
	)
	-- slot_ids should have 2 entries (host + joiner)
	t:eq(#join_data_b.slot_ids, 2)

	-- Player A ready
	pkts_a, err = client_a:match_ready()
	t:eq(err, nil)
	t:ne(find_packet(pkts_a, ServerPackets.UPDATE_MATCH), nil)

	-- Player B ready
	pkts_b, err = client_b:match_ready()
	t:eq(err, nil)
	t:ne(find_packet(pkts_b, ServerPackets.UPDATE_MATCH), nil)

	-- Player A locks
	pkts_a, err = client_a:match_lock(true)
	t:eq(err, nil)
	t:ne(find_packet(pkts_a, ServerPackets.UPDATE_MATCH), nil)

	-- Player A parts
	pkts_a, err = client_a:part_match()
	t:eq(err, nil)
	t:ne(find_packet(pkts_a, ServerPackets.UPDATE_MATCH), nil)

	ctx:close()
end

--- Chat message between two players.
function test.chat_message(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))

	-- Login both
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	-- Both join #general
	client_a:join_channel("#general")
	client_b:join_channel("#general")

	-- Player A sends message
	local pkts_a, err = client_a:send_message("#general", "Hello from A!")
	t:eq(err, nil)

	-- Player B should receive the message on next request
	local pkts_b, err = client_b:ping()
	t:eq(err, nil)
	local msg = extract_message(pkts_b)
	t:eq(msg, "Hello from A!")

	ctx:close()
end

--- Match chat between two players.
function test.match_chat(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))

	-- Login both
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	-- Player A creates match
	local pkts_a, _ = client_a:create_match("Chat Test", "")
	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)

	-- Player B joins match
	local pkts_b, _ = client_b:join_match(match_id)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	-- Player A sends message in match channel
	local channel_name = "#multi_" .. match_id
	pkts_a, _ = client_a:send_message(channel_name, "GG in match!")

	-- Player B should receive the message
	pkts_b, _ = client_b:ping()
	local msg = extract_message(pkts_b)
	t:eq(msg, "GG in match!")

	ctx:close()
end

--- Match ready status is reflected in UPDATE_MATCH.
function test.match_ready_status(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))

	-- Login both
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	-- Create and join match
	local pkts_a, _ = client_a:create_match("Ready Test", "")
	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)
	client_b:join_match(match_id)

	-- Player A ready
	pkts_a, _ = client_a:match_ready()
	local statuses = extract_slot_statuses(pkts_a)
	t:ne(statuses, nil)

	-- Slot 0 (host) should be READY (2), slot 1 should be NOT_READY (1)
	-- SlotStatus: OPEN=0, NOT_READY=1, READY=2
	t:eq(statuses[1], 2) -- Player A is ready
	t:eq(statuses[2], 1) -- Player B is not ready

	-- Player B ready
	pkts_b, _ = client_b:match_ready()
	statuses = extract_slot_statuses(pkts_b)
	t:eq(statuses[1], 2) -- Player A still ready
	t:eq(statuses[2], 2) -- Player B now ready

	ctx:close()
end

return test
