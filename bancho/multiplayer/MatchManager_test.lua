--- Tests for bancho multiplayer MatchManager.

local MatchManager = require("bancho.multiplayer.MatchManager")
local MatchCollection = require("bancho.model.MatchCollection")
local MatchConstants = require("bancho.constants.MatchConstants")
local SlotStatus = require("bancho.constants.SlotStatus")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")

local test = {}

function test.create_match(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	t:assert(m ~= nil)
	t:eq(m.name, "Test Match")
	t:eq(m.host_id, 1)
	t:eq(m.in_progress, false)
end

function test.match_added_to_collection(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	t:assert(mm.matches:get(m.id) ~= nil)
end

function test.add_player_to_match(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	local ok = mm:addPlayer(m, player)
	t:eq(ok, true)
	t:assert(m:getSlot(player) ~= nil)
end

function test.add_player_no_free_slots(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	-- Fill all slots with dummy players
	for i = 0, 15 do
		m.slots[i].status = SlotStatus.NOT_READY
		m.slots[i].player = {id = i}
	end

	local player = {id = 999}
	t:eq(mm:addPlayer(m, player), false)
end

function test.remove_player(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:removePlayer(m, player)

	t:assert(m:getSlot(player) == nil)
end

function test.set_ready(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:setReady(m, player, true)

	local slot = m:getSlot(player)
	t:eq(slot.status, SlotStatus.READY)
end

function test.set_not_ready(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:setReady(m, player, true)
	mm:setReady(m, player, false)

	local slot = m:getSlot(player)
	t:eq(slot.status, SlotStatus.NOT_READY)
end

function test.start_match(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:start(m)

	t:eq(m.in_progress, true)
end

function test.dispose_match(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	mm:dispose(m.id)
	t:eq(mm.matches:get(m.id), nil)
end

function test.get_players(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local p1 = {id = 1}
	local p2 = {id = 2}
	mm:addPlayer(m, p1)
	mm:addPlayer(m, p2)

	local players = mm:getPlayers(m)
	t:eq(#players, 2)
end

function test.transfer_host(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local new_host = {id = 5}
	mm:addPlayer(m, new_host)
	mm:transferHost(m, new_host)

	t:eq(m.host_id, 5)
end

function test.change_password(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	mm:changePassword(m, "newpass")
	t:eq(m.passwd, "newpass")
end

function test.complete_player(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:complete(m, player, {score = 123456})

	local slot = m:getSlot(player)
	t:eq(slot.status, SlotStatus.COMPLETED)
end

function test.fail_player(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	mm:addPlayer(m, player)
	mm:fail(m, player)

	local slot = m:getSlot(player)
	t:eq(slot.status, SlotStatus.FAILED)
end

function test.all_ready(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local p1 = {id = 1}
	local p2 = {id = 2}
	mm:addPlayer(m, p1)
	mm:addPlayer(m, p2)

	-- Not ready by default
	t:eq(mm:allReady(m), false)

	-- Ready both
	mm:setReady(m, p1, true)
	mm:setReady(m, p2, true)
	t:eq(mm:allReady(m), true)
end

function test.build_match_data(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local p1 = {id = 1}
	mm:addPlayer(m, p1)

	local data = mm:buildMatchData(m)
	t:eq(data.id, m.id)
	t:eq(data.name, m.name)
	t:eq(#data.slot_statuses, 16)
	t:eq(#data.slot_teams, 16)
	t:eq(#data.slot_ids, 1) -- only 1 player
	t:eq(data.host_id, 1)
end

function test.get_players_by_status(t)
	local mm = MatchManager(MatchCollection())
	local m = mm:create("Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local p1 = {id = 1}
	local p2 = {id = 2}
	mm:addPlayer(m, p1)
	mm:addPlayer(m, p2)
	mm:setReady(m, p1, true)

	local ready = mm:getPlayersByStatus(m, SlotStatus.READY)
	t:eq(#ready, 1)

	local not_ready = mm:getPlayersByStatus(m, SlotStatus.NOT_READY)
	t:eq(#not_ready, 1)
end

return test
