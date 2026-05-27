--- Tests for bancho model Match.

local Match = require("bancho.model.Match")
local MatchConstants = require("bancho.constants.MatchConstants")
local SlotStatus = require("bancho.constants.SlotStatus")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")

local test = {}

function test.match_creation(t)
	local m = Match:new(1, "Test Match", "pass", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	t:eq(m.id, 1)
	t:eq(m.name, "Test Match")
	t:eq(m.passwd, "pass")
	t:eq(m.host_id, 1)
	t:eq(m.mode, GameMode.VANILLA_OSU)
	t:eq(m.in_progress, false)
	t:eq(m.freemods, false)

	-- All 16 slots are open
	for i = 0, 15 do
		t:eq(m.slots[i].status, SlotStatus.OPEN)
		t:assert(m.slots[i]:empty())
	end
end

function test.match_getFree(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	t:eq(m:getFree(), 0) -- first slot is free
end

function test.match_getSlot_byPlayer(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	-- Fake player table
	local player = {id = 42}
	m.slots[3].player = player
	m.slots[3].status = SlotStatus.READY

	local slot = m:getSlot(player)
	t:assert(slot ~= nil)
	t:eq(slot.player, player)
	t:eq(slot.status, SlotStatus.READY)

	-- Non-existent player
	t:assert(m:getSlot({id = 99}) == nil)
end

function test.match_getSlotId(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	m.slots[7].player = player
	m.slots[7].status = SlotStatus.READY

	t:eq(m:getSlotId(player), 7)
	t:assert(m:getSlotId({id = 99}) == nil)
end

function test.match_getFree_noFreeSlots(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	-- Fill all slots (except index 0 which is open)
	for i = 1, 15 do
		m.slots[i].status = SlotStatus.NOT_READY
	end

	t:eq(m:getFree(), 0) -- index 0 is still open
end

function test.match_slotReset(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	local slot = m.slots[3]
	slot.player = player
	slot.status = SlotStatus.PLAYING
	slot.team = MatchConstants.MatchTeams.RED
	slot.mods = bit.bor(Mods.HIDDEN, Mods.DOUBLETIME)
	slot.loaded = true

	slot:reset()

	t:assert(slot:empty())
	t:eq(slot.status, SlotStatus.OPEN)
	t:eq(slot.team, MatchConstants.MatchTeams.NEUTRAL)
	t:eq(slot.mods, Mods.NOMOD)
	t:eq(slot.loaded, false)
end

function test.match_slotCopyFrom(t)
	local m = Match:new(1, "Test", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	local player = {id = 42}
	local src = m.slots[2]
	src.player = player
	src.status = SlotStatus.READY
	src.team = MatchConstants.MatchTeams.BLUE
	src.mods = bit.bor(Mods.HIDDEN)
	src.loaded = true

	local dst = m.slots[5]
	dst:copyFrom(src)

	t:eq(dst.player, player)
	t:eq(dst.status, SlotStatus.READY)
	t:eq(dst.team, MatchConstants.MatchTeams.BLUE)
	t:eq(bit.band(dst.mods, Mods.HIDDEN), Mods.HIDDEN)
	t:eq(dst.loaded, true)
end

return test
