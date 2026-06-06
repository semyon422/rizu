local bit = require("bit")
local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local ClientPackets = require("bancho.protocol.ClientPackets")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local MatchConstants = require("bancho.constants.MatchConstants")
local Mods = require("bancho.constants.Mods")
local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local md5 = require("md5")

local test = {}

---@param client bancho.client.BanchoClient
---@param match bancho.protocol.MultiplayerMatch
---@param overrides table
local function send_match_settings(client, match, overrides)
	local next_match = {
		id = match.id,
		in_progress = match.in_progress,
		powerplay = match.powerplay,
		mods = match.mods,
		name = match.name,
		passwd = match.passwd,
		map_name = match.map_name,
		map_id = match.map_id,
		map_md5 = match.map_md5,
		slot_statuses = match.slot_statuses,
		slot_teams = match.slot_teams,
		slot_ids = match.slot_ids,
		host_id = match.host_id,
		mode = match.mode,
		win_condition = match.win_condition,
		team_type = match.team_type,
		freemods = match.freemods,
		slot_mods = match.slot_mods,
		seed = match.seed,
	}
	for k, v in pairs(overrides) do
		next_match[k] = v
	end
	if next_match.freemods and not next_match.slot_mods then
		next_match.slot_mods = {}
		for _ = 1, 16 do
			next_match.slot_mods[#next_match.slot_mods + 1] = 0
		end
	end
	local body = ComplexTypes.writeMatch(next_match)
	return client:send(client:build_packet(ClientPackets.MATCH_CHANGE_SETTINGS, body))
end

---@param statuses integer[]
---@return integer
local function occupied_count(statuses)
	local occupied = 0
	for _, s in ipairs(statuses) do
		if bit.band(s, 124) ~= 0 then
			occupied = occupied + 1
		end
	end
	return occupied
end

---@param t testing.T
function test.create_and_part_match(t)
	local ctx = E2EContext()
	ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)

	local client = TestLib.createClient(ctx, "TestUser", md5.sumhexa("testpass"))
	t:eq(client:login().success, true)

	local pkts = select(1, client:create_match("Test Match", ""))
	t:ne(TestLib.findPacket(pkts, ServerPackets.MATCH_JOIN_SUCCESS), nil)
	t:ne(TestLib.extractMatchId(pkts), nil)

	local part_pkts = select(1, client:part_match())
	t:eq(#part_pkts, 0)

	ctx:close()
end

---@param t testing.T
function test.two_player_match(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:create_match("Duel", ""))
	local match_id = TestLib.extractMatchId(pkts_a)
	t:ne(match_id, nil)

	local pkts_b = select(1, client_b:join_match(match_id))
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	pkts_a = select(1, client_a:ping())
	local statuses = TestLib.extractSlotStatuses(pkts_a)
	t:ne(statuses, nil)
	t:eq(occupied_count(statuses), 2)

	ctx:close()
end

---@param t testing.T
function test.password_join_requires_correct_password(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:create_match("Locked Room", "secret"))
	local match_id = TestLib.extractMatchId(pkts_a)
	t:ne(match_id, nil)

	local pkts_b = select(1, client_b:join_match(match_id, "wrong"))
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_JOIN_FAIL), nil)

	pkts_b = select(1, client_b:join_match(match_id, "secret"))
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	ctx:close()
end

---@param t testing.T
function test.match_ready_status(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Ready Test", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:match_ready())
	local statuses = TestLib.extractSlotStatuses(pkts_a)
	t:eq(statuses[1], SlotStatus.READY)
	t:eq(statuses[2], SlotStatus.NOT_READY)

	local pkts_b = select(1, client_b:match_ready())
	statuses = TestLib.extractSlotStatuses(pkts_b)
	t:eq(statuses[1], SlotStatus.READY)
	t:eq(statuses[2], SlotStatus.READY)

	ctx:close()
end

---@param t testing.T
function test.match_start_ui_two_players(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("UI Start", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	client_b:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:match_start())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_START), nil)
	local statuses = TestLib.extractSlotStatuses(pkts_a)
	t:eq(statuses[1], SlotStatus.PLAYING)
	t:eq(statuses[2], SlotStatus.PLAYING)

	local pkts_b = select(1, client_b:ping())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_START), nil)

	ctx:close()
end

---@param t testing.T
function test.no_map_player_is_excluded_from_start(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("No Map", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_a:match_ready()
	client_b:match_no_beatmap()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:match_start())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_START), nil)
	local statuses = TestLib.extractSlotStatuses(pkts_a)
	t:eq(statuses[1], SlotStatus.PLAYING)
	t:eq(statuses[2], SlotStatus.NO_MAP)

	local pkts_b = select(1, client_b:ping())
	t:eq(TestLib.findPacket(pkts_b, ServerPackets.MATCH_START), nil)

	ctx:close()
end

---@param t testing.T
function test.match_load_complete_notifies_all_players_loaded(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Load Test", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	client_b:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_start()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:match_load_complete())
	t:eq(TestLib.findPacket(pkts_a, ServerPackets.MATCH_ALL_PLAYERS_LOADED), nil)

	local pkts_b = select(1, client_b:match_load_complete())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_ALL_PLAYERS_LOADED), nil)

	pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_ALL_PLAYERS_LOADED), nil)

	ctx:close()
end

---@param t testing.T
function test.match_complete_resets_state_after_all_players_finish(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Complete Test", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	client_b:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_start()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:match_complete())
	t:eq(TestLib.findPacket(pkts_a, ServerPackets.MATCH_COMPLETE), nil)

	local pkts_b = select(1, client_b:match_complete())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_COMPLETE), nil)
	local match = TestLib.extractUpdatedMatch(pkts_b)
	t:ne(match, nil)
	t:eq(match.in_progress, false)
	t:eq(match.slot_statuses[1], SlotStatus.NOT_READY)
	t:eq(match.slot_statuses[2], SlotStatus.NOT_READY)

	pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_COMPLETE), nil)

	ctx:close()
end

---@param t testing.T
function test.host_transfers_when_host_parts_during_match(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Host Leave", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	client_b:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_start()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_a:part_match()
	local pkts_b = select(1, client_b:ping())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_TRANSFER_HOST), nil)

	ctx:close()
end

---@param t testing.T
function test.match_lock_and_unlock_slot(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client_a:login().success, true)
	TestLib.drain(client_a)

	TestLib.extractMatchId(select(1, client_a:create_match("Lock Test", "")))
	local pkts_a = select(1, client_a:match_lock(1))
	local statuses = TestLib.extractSlotStatuses(pkts_a)
	t:eq(statuses[2], SlotStatus.LOCKED)

	pkts_a = select(1, client_a:match_lock(1))
	statuses = TestLib.extractSlotStatuses(pkts_a)
	t:eq(statuses[2], SlotStatus.OPEN)

	ctx:close()
end

---@param t testing.T
function test.match_change_team_updates_slot_team(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Team Test", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_b = select(1, client_b:match_change_team(0))
	local teams = TestLib.extractSlotTeams(pkts_b)
	t:eq(teams[2], MatchConstants.MatchTeams.BLUE)

	ctx:close()
end

---@param t testing.T
function test.match_change_mods_updates_match_state(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client_a:login().success, true)
	TestLib.drain(client_a)

	TestLib.extractMatchId(select(1, client_a:create_match("Mods Test", "")))
	local pkts_a = select(1, client_a:match_change_mods(Mods.HIDDEN))
	local match = TestLib.extractUpdatedMatch(pkts_a)
	t:ne(match, nil)
	t:eq(match.mods, Mods.HIDDEN)

	ctx:close()
end

---@param t testing.T
function test.freemods_splits_speed_and_slot_mods(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client_a:login().success, true)
	TestLib.drain(client_a)

	local pkts_a = select(1, client_a:create_match("Freemods Test", ""))
	local match = TestLib.extractJoinMatch(pkts_a)
	t:ne(match, nil)

	pkts_a = select(1, send_match_settings(client_a, match, {freemods = true}))
	local updated = TestLib.extractUpdatedMatch(pkts_a)
	t:ne(updated, nil)
	t:eq(updated.freemods, true)

	pkts_a = select(1, client_a:match_change_mods(bit.bor(Mods.DOUBLETIME, Mods.HIDDEN)))
	updated = TestLib.extractUpdatedMatch(pkts_a)
	t:eq(updated.mods, Mods.DOUBLETIME)
	t:eq(updated.slot_mods[1], Mods.HIDDEN)

	ctx:close()
end

---@param t testing.T
function test.match_failed_and_skip_packets(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Flow Test", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	client_b:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_start()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_b:match_failed()
	local pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_PLAYER_FAILED), nil)

	local pkts_b = select(1, client_b:match_skip())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_PLAYER_SKIPPED), nil)
	pkts_a = select(1, client_a:match_skip())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_SKIP), nil)

	ctx:close()
end

return test
