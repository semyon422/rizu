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

local bit = require("bit")
local E2EContext = require("bancho.e2e.E2EContext")
local FakeHttpTransport = require("bancho.e2e.FakeHttpTransport")
local BanchoClient = require("bancho.client.BanchoClient")
local ClientConfig = require("bancho.client.ClientConfig")
local Binary = require("bancho.protocol.Binary")
local ServerPackets = require("bancho.protocol.ServerPackets")
local md5 = require("md5")
local Repos = require("bancho.db.repos")

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
	local pkt
	for _, candidate in ipairs(packets) do
		if candidate.id == ServerPackets.UPDATE_MATCH then
			pkt = candidate
		end
	end
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

---@param pkt bancho.client.IncomingPacket
---@return number accuracy
local function extract_stats_accuracy(pkt)
	local reader = require("bancho.protocol.PacketReader")(pkt.body)
	reader:readI32()
	reader:readU8()
	reader:readString()
	reader:readString()
	reader:readI32()
	reader:readU8()
	reader:readI32()
	reader:skip(8)
	return reader:readF32()
end

---@param pkt bancho.client.IncomingPacket
---@return integer global_rank
local function extract_presence_rank(pkt)
	local reader = require("bancho.protocol.PacketReader")(pkt.body)
	reader:readI32()
	reader:readString()
	reader:readU8()
	reader:readU8()
	reader:readU8()
	reader:readF32()
	reader:readF32()
	return reader:readI32()
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

function test.login_sends_ranked_presence_and_normalized_stats(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	local repos = Repos(ctx.db.models)
	repos.stats_repo:updateStats(user_id, 0, {
		rank = 321,
		acc = 98.76,
		pp = 456,
	})

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)

	local presence_pkt = find_packet(result.packets, ServerPackets.USER_PRESENCE)
	t:ne(presence_pkt, nil)
	t:eq(extract_presence_rank(presence_pkt), 321)

	local stats_pkt = find_packet(result.packets, ServerPackets.USER_STATS)
	t:ne(stats_pkt, nil)
	t:aeq(extract_stats_accuracy(stats_pkt), 0.9876, 0.0001)

	ctx:close()
end

function test.change_action_sends_updated_stats_to_self(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	local repos = Repos(ctx.db.models)
	repos.stats_repo:updateStats(user_id, 3, {
		plays = 12,
		acc = 97.5,
		pp = 321,
		rank = 123,
	})

	local client = create_e2e_client(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)

	local body = Binary.writeU8(0)
		.. Binary.writeString("")
		.. Binary.writeString("")
		.. Binary.writeU32(0)
		.. Binary.writeU8(3)
		.. Binary.writeI32(0)
	local packet = Binary.writeHeader(0, #body) .. body

	local packets, err = client:send(packet)
	t:eq(err, nil)

	local stats_pkt = find_packet(packets, ServerPackets.USER_STATS)
	t:ne(stats_pkt, nil)
	t:aeq(extract_stats_accuracy(stats_pkt), 0.975, 0.0001)

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

	-- Part match as the only player; room is disposed.
	pkts, err = client:part_match()
	t:eq(err, nil)

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

	-- Host should receive an updated match state on the next request.
	pkts_a, err = client_a:ping()
	t:eq(err, nil)
	local host_slot_statuses = extract_slot_statuses(pkts_a)
	t:ne(host_slot_statuses, nil)
	local host_occupied = 0
	for _, s in ipairs(host_slot_statuses) do
		if bit.band(s, 124) ~= 0 then host_occupied = host_occupied + 1 end
	end
	t:eq(host_occupied, 2)

	-- Verify both players are in the match
	local join_data_b = require("bancho.protocol.ComplexTypes").readMatch(
		require("bancho.protocol.PacketReader")(
			find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS).body
		)
	)
	-- slot_ids are only sent for slots with status & 124 != 0.
	-- Count occupied slots via the same bitmask Bancho uses.
	local occupied = 0
	for _, s in ipairs(join_data_b.slot_statuses) do
		if bit.band(s, 124) ~= 0 then occupied = occupied + 1 end
	end
	t:eq(occupied, 2)

	-- Player A ready
	pkts_a, err = client_a:match_ready()
	t:eq(err, nil)
	t:ne(find_packet(pkts_a, ServerPackets.UPDATE_MATCH), nil)

	-- Player B ready
	pkts_b, err = client_b:match_ready()
	t:eq(err, nil)
	t:ne(find_packet(pkts_b, ServerPackets.UPDATE_MATCH), nil)

	-- Player A locks (test client targets host slot 0, which is ignored)
	pkts_a, err = client_a:match_lock(true)
	t:eq(err, nil)

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
	t:ne(find_packet(pkts_a, ServerPackets.CHANNEL_JOIN_SUCCESS), nil)

	-- Player B joins match
	local pkts_b, _ = client_b:join_match(match_id)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)
	t:ne(find_packet(pkts_b, ServerPackets.CHANNEL_JOIN_SUCCESS), nil)

	-- Player A sends message in match channel
	pkts_a, _ = client_a:send_message("#multiplayer", "GG in match!")

	-- Player B should receive the message
	pkts_b, _ = client_b:ping()
	local msg = extract_message(pkts_b)
	t:eq(msg, "GG in match!")

	ctx:close()
end

function test.match_command_start_solo(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client_a:login().success, true)

	local pkts_a, _ = client_a:create_match("Solo Start", "")
	t:ne(find_packet(pkts_a, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	pkts_a, _ = client_a:send_message("#multiplayer", "!mp start")
	t:ne(find_packet(pkts_a, ServerPackets.MATCH_START), nil)
	local msg = extract_message(pkts_a)
	t:eq(msg, "Good luck!")

	ctx:close()
end

function test.match_command_transfer_host(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts_a, _ = client_a:create_match("Host Transfer", "")
	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)
	local pkts_b, _ = client_b:join_match(match_id)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	pkts_a, _ = client_a:send_message("#multiplayer", "!mp host PlayerB")
	t:eq(extract_message(pkts_a), "Match host transferred.")

	pkts_b, _ = client_b:ping()
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_TRANSFER_HOST), nil)
	local statuses = extract_slot_statuses(pkts_b)
	t:ne(statuses, nil)

	ctx:close()
end

function test.match_start_ui_two_players(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts_a, _ = client_a:create_match("UI Start", "")
	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)
	local pkts_b, _ = client_b:join_match(match_id)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	client_a:match_ready()
	client_b:match_ready()

	pkts_a, _ = client_a:match_start()
	t:ne(find_packet(pkts_a, ServerPackets.MATCH_START), nil)
	local statuses = extract_slot_statuses(pkts_a)
	t:ne(statuses, nil)
	t:eq(statuses[1], 32)
	t:eq(statuses[2], 32)

	pkts_b, _ = client_b:ping()
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_START), nil)

	ctx:close()
end

function test.host_transfers_when_host_parts_match(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts_a, _ = client_a:create_match("Host Leave", "")
	local match_id = extract_match_id(pkts_a)
	t:ne(match_id, nil)
	local pkts_b, _ = client_b:join_match(match_id)
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	client_a:part_match()
	pkts_b, _ = client_b:ping()
	t:ne(find_packet(pkts_b, ServerPackets.MATCH_TRANSFER_HOST), nil)
	local statuses = extract_slot_statuses(pkts_b)
	t:ne(statuses, nil)

	ctx:close()
end

function test.friend_add_remove(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = Repos(ctx.db.models)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts_a, err = client_a:add_friend(user_b)
	t:eq(err, nil)
	t:eq(repos.friends_repo:isFriend(user_a, user_b), true)
	t:ne(find_packet(pkts_a, ServerPackets.USER_PRESENCE), nil)

	pkts_a, err = client_a:remove_friend(user_b)
	t:eq(err, nil)
	t:eq(repos.friends_repo:isFriend(user_a, user_b), false)

	ctx:close()
end

function test.user_stats_and_presence_request(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = Repos(ctx.db.models)
	repos.stats_repo:updateStats(user_b, 0, {
		rank = 123,
		acc = 98.5,
		pp = 456,
	})

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts, err = client_a:request_user_stats(user_b)
	t:eq(err, nil)
	local stats_pkt = find_packet(pkts, ServerPackets.USER_STATS)
	t:ne(stats_pkt, nil)
	t:aeq(extract_stats_accuracy(stats_pkt), 0.985, 0.0001)

	pkts, err = client_a:request_user_presence(user_b)
	t:eq(err, nil)
	local presence_pkt = find_packet(pkts, ServerPackets.USER_PRESENCE)
	t:ne(presence_pkt, nil)
	t:eq(extract_presence_rank(presence_pkt), 123)

	ctx:close()
end

function test.join_lobby_receives_existing_matches(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = create_e2e_client(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = create_e2e_client(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)

	local pkts_a, _ = client_a:create_match("Lobby Test", "")
	t:ne(extract_match_id(pkts_a), nil)

	local pkts_b, err = client_b:join_lobby()
	t:eq(err, nil)
	t:ne(find_packet(pkts_b, ServerPackets.NEW_MATCH), nil)

	pkts_b, err = client_b:part_lobby()
	t:eq(err, nil)
	t:eq(#pkts_b, 0)

	ctx:close()
end

--- Score submission via ScoreSubmitter:submit.
--- Tests the core submission logic: checksum validation, PP calculation, persistence.
function test.score_submission(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	t:eq(user_id, 1)

	-- Create a beatmap in the database
	local Repos = require("bancho.db.repos")
	local repos = Repos(ctx.db.models)
	local bmap_md5 = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
	repos.beatmap_repo:addBeatmap({
		id = 12345,
		set_id = 1234,
		md5 = bmap_md5,
		artist = "TestArtist",
		title = "TestTitle",
		version = "Easy",
		creator = "TestCreator",
		status = 2, -- ranked
		diff = 5.0,
		od = 7,
		mode = 3, -- mania
	})

	-- Create server with shared memory and repos
	local BanchoServer = require("bancho.server.BanchoServer")
	local server = BanchoServer(ctx.shared_memory)
	server:setRepos(
		repos.user_repo, repos.score_repo, repos.beatmap_repo,
		repos.friends_repo, repos.favourites_repo, repos.stats_repo, repos.replay_repo
	)

	-- Login the player via BanchoProtocolResource
	local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
	local proto_resource = BanchoProtocolResource(server)

	-- Build login request
	local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
	local Request = require("web.http.Request")
	local Response = require("web.http.Response")

	local login_soc = ExtendedStringSocket()
	local login_res_soc = login_soc:split()

	local login_body = table.concat({
		"TestUser",
		md5.sumhexa("testpass"),
		"b20240101|0|0|hash1:adapters:hash2:hash3:hash4:|0",
	}, "\n") .. "\n"

	local login_request = {
		"POST / HTTP/1.1",
		"Host: osu.example.com",
		"Content-Length: " .. #login_body,
		"",
		login_body,
	}
	login_res_soc:send(table.concat(login_request, "\r\n"))

	local login_req = Request(login_soc, "r")
	local login_res = Response(login_res_soc, "w")
	proto_resource:handleProtocol(login_req, login_res)

	-- Verify player is online
	local player = server.players:get(nil, nil, "TestUser")
	t:ne(player, nil)
	t:eq(player.id, user_id)

	-- Prepare score data
	local username = "TestUser"
	local osu_version = "20240101"
	local client_hash = "test_client_hash_1234567890123456789012345678901234567890123456789012"
	local storyboard_md5 = ""

	-- Score fields (mania mode)
	local n300 = 500
	local n100 = 200
	local n50 = 50
	local ngeki = 100
	local nkatu = 50
	local nmiss = 0
	local score_value = 999999
	local max_combo = 1000
	local perfect = false
	local grade = "x"
	local mods = 0
	local passed = true
	local mode = 3
	local play_time = "240101120000"

	-- Compute the online checksum using Score:computeOnlineChecksum
	local Score = require("bancho.model.Score")
	local temp_score = Score:new()
	temp_score.n300 = n300
	temp_score.n100 = n100
	temp_score.n50 = n50
	temp_score.ngeki = ngeki
	temp_score.nkatu = nkatu
	temp_score.nmiss = nmiss
	temp_score.score = score_value
	temp_score.max_combo = max_combo
	temp_score.perfect = perfect
	temp_score.grade = require("bancho.constants.Grade").fromString(grade)
	temp_score.mods = mods
	temp_score.passed = passed
	temp_score.mode = mode
	temp_score.client_time = play_time

	local checksum = temp_score:computeOnlineChecksum(
		username,
		bmap_md5,
		osu_version,
		client_hash,
		storyboard_md5
	)

	-- Build parts array: [1]=map_md5, [2]=username, [3..]=score fields
	-- Score fields: online_checksum, n300, n100, n50, ngeki, nkatu, nmiss, score, max_combo, perfect, grade, mods, passed, mode, play_time
	local parts = {
		bmap_md5,          -- [1] map_md5
		username,          -- [2] username
		checksum,          -- [3] online_checksum
		tostring(n300),    -- [4] n300
		tostring(n100),    -- [5] n100
		tostring(n50),     -- [6] n50
		tostring(ngeki),   -- [7] ngeki
		tostring(nkatu),   -- [8] nkatu
		tostring(nmiss),   -- [9] nmiss
		tostring(score_value), -- [10] score
		tostring(max_combo),   -- [11] max_combo
		perfect and "True" or "False", -- [12] perfect
		grade,             -- [13] grade
		tostring(mods),    -- [14] mods
		passed and "True" or "False", -- [15] passed
		tostring(mode),    -- [16] mode
		play_time,         -- [17] play_time
	}

	-- Build fields table
	local fields = {
		osuver = osu_version,
		client_hash = client_hash,
		sbk = storyboard_md5,
		st = "60000", -- time elapsed in milliseconds
	}

	-- Submit score directly via ScoreSubmitter
	local chart_response = server.score_submitter:submit(player, parts, "fake_replay", fields)

	-- Verify chart response is not nil
	t:ne(chart_response, nil)
	t:ne(chart_response, "")

	-- Verify score was saved to database
	local saved_score = repos.score_repo:findBestScore(bmap_md5, user_id, mode)
	t:ne(saved_score, nil)
	t:eq(saved_score.score, score_value)
	t:eq(saved_score.n300, n300)
	t:eq(saved_score.n100, n100)
	t:eq(saved_score.nmiss, nmiss)
	t:eq(saved_score.grade, require("bancho.constants.Grade").X.value)

	ctx:close()
end

--- Stats persistence: submit score, verify DB and in-memory stats, then re-login and verify stats loaded from DB.
function test.stats_persistence(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("StatsUser", md5.sumhexa("testpass"), 0)
	t:eq(user_id, 1)

	-- Create a beatmap in the database
	local Repos = require("bancho.db.repos")
	local repos = Repos(ctx.db.models)
	local bmap_md5 = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
	repos.beatmap_repo:addBeatmap({
		id = 12345,
		set_id = 1234,
		md5 = bmap_md5,
		artist = "TestArtist",
		title = "TestTitle",
		version = "Easy",
		creator = "TestCreator",
		status = 2, -- ranked
		diff = 5.0,
		od = 7,
		mode = 0, -- osu!
	})

	-- Create server with shared memory and repos
	local BanchoServer = require("bancho.server.BanchoServer")
	local server = BanchoServer(ctx.shared_memory)
	server:setRepos(
		repos.user_repo, repos.score_repo, repos.beatmap_repo,
		repos.friends_repo, repos.favourites_repo, repos.stats_repo, repos.replay_repo
	)

	-- Login the player via BanchoProtocolResource
	local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
	local proto_resource = BanchoProtocolResource(server)

	local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
	local Request = require("web.http.Request")
	local Response = require("web.http.Response")

	local login_soc = ExtendedStringSocket()
	local login_res_soc = login_soc:split()

	local login_body = table.concat({
		"StatsUser",
		md5.sumhexa("testpass"),
		"b20240101|0|0|hash1:adapters:hash2:hash3:hash4:|0",
	}, "\n") .. "\n"

	local login_request = {
		"POST / HTTP/1.1",
		"Host: osu.example.com",
		"Content-Length: " .. #login_body,
		"",
		login_body,
	}
	login_res_soc:send(table.concat(login_request, "\r\n"))

	local login_req = Request(login_soc, "r")
	local login_res = Response(login_res_soc, "w")
	proto_resource:handleProtocol(login_req, login_res)

	-- Verify player is online
	local player = server.players:get(nil, nil, "StatsUser")
	t:ne(player, nil)

	-- Verify DB stats are nil (no scores yet)
	local db_stats = repos.stats_repo:getStats(user_id, 0)
	t:eq(db_stats, nil)

	-- Prepare score data (osu! mode)
	local username = "StatsUser"
	local osu_version = "20240101"
	local client_hash = "test_client_hash_1234567890123456789012345678901234567890123456789012"
	local storyboard_md5 = ""

	local n300 = 500
	local n100 = 200
	local n50 = 50
	local ngeki = 0
	local nkatu = 0
	local nmiss = 0
	local score_value = 999999
	local max_combo = 1000
	local perfect = false
	local grade = "x"
	local mods = 0
	local passed = true
	local mode = 0
	local play_time = "240101120000"

	-- Compute the online checksum
	local Score = require("bancho.model.Score")
	local temp_score = Score:new()
	temp_score.n300 = n300
	temp_score.n100 = n100
	temp_score.n50 = n50
	temp_score.ngeki = ngeki
	temp_score.nkatu = nkatu
	temp_score.nmiss = nmiss
	temp_score.score = score_value
	temp_score.max_combo = max_combo
	temp_score.perfect = perfect
	temp_score.grade = require("bancho.constants.Grade").fromString(grade)
	temp_score.mods = mods
	temp_score.passed = passed
	temp_score.mode = mode
	temp_score.client_time = play_time

	local checksum = temp_score:computeOnlineChecksum(
		username,
		bmap_md5,
		osu_version,
		client_hash,
		storyboard_md5
	)

	-- Build parts array
	local parts = {
		bmap_md5,          -- [1] map_md5
		username,          -- [2] username
		checksum,          -- [3] online_checksum
		tostring(n300),    -- [4] n300
		tostring(n100),    -- [5] n100
		tostring(n50),     -- [6] n50
		tostring(ngeki),   -- [7] ngeki
		tostring(nkatu),   -- [8] nkatu
		tostring(nmiss),   -- [9] nmiss
		tostring(score_value), -- [10] score
		tostring(max_combo),   -- [11] max_combo
		perfect and "True" or "False", -- [12] perfect
		grade,             -- [13] grade
		tostring(mods),    -- [14] mods
		passed and "True" or "False", -- [15] passed
		tostring(mode),    -- [16] mode
		play_time,         -- [17] play_time
	}

	local fields = {
		osuver = osu_version,
		client_hash = client_hash,
		sbk = storyboard_md5,
		st = "60000",
	}

	-- Submit score
	local chart_response = server.score_submitter:submit(player, parts, "fake_replay", fields)
	t:ne(chart_response, nil)

	-- Verify DB stats are updated
	db_stats = repos.stats_repo:getStats(user_id, 0)
	t:ne(db_stats, nil)
	t:eq(db_stats.plays, 1)
	t:eq(db_stats.tscore, score_value)

	-- Verify ranked stats are updated (map is ranked, score is new best)
	t:eq(db_stats.rscore, score_value, "rscore should equal score value for first ranked score")
	-- Note: pp is 0 for osu!std (not yet implemented), non-zero for mania
	t:ne(db_stats.acc, 0, "acc should be calculated")
	t:eq(db_stats.rank, 1, "rank should be 1 for first user")
	t:eq(db_stats.x_count, 1, "x_count should be 1 for X grade")
	t:eq(db_stats.s_count, 0, "s_count should be 0")
	t:eq(db_stats.a_count, 0, "a_count should be 0")

	-- Now simulate a new worker: create a fresh server and verify stats are loaded from DB
	local server2 = BanchoServer(ctx.shared_memory)
	server2:setRepos(
		repos.user_repo, repos.score_repo, repos.beatmap_repo,
		repos.friends_repo, repos.favourites_repo, repos.stats_repo, repos.replay_repo
	)

	local proto_resource2 = BanchoProtocolResource(server2)
	local login_soc2 = ExtendedStringSocket()
	local login_res_soc2 = login_soc2:split()

	login_res_soc2:send(table.concat(login_request, "\r\n"))
	local login_req2 = Request(login_soc2, "r")
	local login_res2 = Response(login_res_soc2, "w")
	proto_resource2:handleProtocol(login_req2, login_res2)

	-- Verify the re-logged-in player is online
	local player2 = server2.players:get(nil, nil, "StatsUser")
	t:ne(player2, nil)

	-- Verify DB stats are still correct (stats always come from DB)
	local db_stats2 = repos.stats_repo:getStats(user_id, 0)
	t:ne(db_stats2, nil)
	t:eq(db_stats2.plays, 1)
	t:eq(db_stats2.tscore, score_value)

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

	-- Slot 0 (host) should be READY, slot 1 should be NOT_READY.
	t:eq(statuses[1], 8) -- Player A is ready
	t:eq(statuses[2], 4) -- Player B is not ready

	-- Player B ready
	pkts_b, _ = client_b:match_ready()
	statuses = extract_slot_statuses(pkts_b)
	t:eq(statuses[1], 8) -- Player A still ready
	t:eq(statuses[2], 8) -- Player B now ready

	ctx:close()
end

-- ============================================================
-- Registration Flow Tests
-- ============================================================

--- Register user via AccountResource then login.
function test.register_and_login(t)
	local ctx = E2EContext()

	-- Register via AccountResource
	local account_resource = ctx:createAccountResource()
	local username = "NewPlayer"
	local email = "newplayer@test.com"
	local password = "testpass123"

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = username,
		["user[user_email]"] = email,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req, res)

	-- Read response body
	local response_body = ctx:readHttpResponse(read_soc)
	t:eq(response_body, "ok")

	-- Verify user was created in DB
	local repos = Repos(ctx.db.models)
	local user = repos.user_repo:findUserByName(username)
	t:ne(user, nil)
	t:eq(user.name, username)
	t:eq(user.email, email)

	-- Verify stats were created for all modes
	for mode = 0, 3 do
		local stats = repos.stats_repo:getStats(user.id, mode)
		t:ne(stats, nil)
		t:eq(stats.plays, 0)
		t:eq(stats.tscore, 0)
	end

	-- Login with the new user
	local client = create_e2e_client(ctx, username, md5.sumhexa(password))
	local result = client:login()
	t:eq(result.success, true)
	t:ne(result.user_id, -1)
	t:eq(result.user_id, user.id)

	-- Verify stats are accessible via stats_repo
	local stats = repos.stats_repo:getStats(user.id, 0)
	t:ne(stats, nil)
	t:eq(stats.plays, 0)
	t:eq(stats.tscore, 0)

	ctx:close()
end

--- Registration with duplicate username fails.
function test.register_duplicate_username(t)
	local ctx = E2EContext()

	-- Create first user
	local account_resource = ctx:createAccountResource()
	local username = "DupPlayer"
	local email1 = "dup1@test.com"
	local email2 = "dup2@test.com"
	local password = "testpass123"

	-- First registration
	local req1, res1, read_soc1 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = username,
		["user[user_email]"] = email1,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req1, res1)
	t:eq(ctx:readHttpResponse(read_soc1), "ok")

	-- Second registration with same username
	local req2, res2, read_soc2 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = username,
		["user[user_email]"] = email2,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req2, res2)
	local response_body = ctx:readHttpResponse(read_soc2)
	t:ne(response_body, "ok")
	t:ne(response_body:find("Username already taken"), nil)

	ctx:close()
end

--- Registration with duplicate email fails.
function test.register_duplicate_email(t)
	local ctx = E2EContext()

	local account_resource = ctx:createAccountResource()
	local email = "same@test.com"
	local password = "testpass123"

	-- First registration
	local req1, res1, read_soc1 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "player1",
		["user[user_email]"] = email,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req1, res1)
	t:eq(ctx:readHttpResponse(read_soc1), "ok")

	-- Second registration with same email
	local req2, res2, read_soc2 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "player2",
		["user[user_email]"] = email,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req2, res2)
	local response_body = ctx:readHttpResponse(read_soc2)
	t:ne(response_body, "ok")
	t:ne(response_body:find("Email already taken"), nil)

	ctx:close()
end

--- Registration with short username fails.
function test.register_short_username(t)
	local ctx = E2EContext()

	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "A",
		["user[user_email]"] = "a@test.com",
		["user[password]"] = "testpass123",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local response_body = ctx:readHttpResponse(read_soc)
	t:ne(response_body, "ok")
	t:ne(response_body:find("2-15 characters"), nil)

	ctx:close()
end

--- Registration with short password fails.
function test.register_short_password(t)
	local ctx = E2EContext()

	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "TestUser",
		["user[user_email]"] = "test@test.com",
		["user[password]"] = "short",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local response_body = ctx:readHttpResponse(read_soc)
	t:ne(response_body, "ok")
	t:ne(response_body:find("8-32 characters"), nil)

	ctx:close()
end

--- Registration with invalid email fails.
function test.register_invalid_email(t)
	local ctx = E2EContext()

	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "TestUser",
		["user[user_email]"] = "notanemail",
		["user[password]"] = "testpass123",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local response_body = ctx:readHttpResponse(read_soc)
	t:ne(response_body, "ok")
	t:ne(response_body:find("Invalid email"), nil)

	ctx:close()
end

return test
