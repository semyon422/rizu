--- Tests for bancho model MatchCollection.

local MatchCollection = require("bancho.model.MatchCollection")
local Match = require("bancho.model.Match")
local MatchConstants = require("bancho.constants.MatchConstants")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")

local test = {}

function test.collection_empty(t)
	local c = MatchCollection()
	t:eq(c:get(1), nil)
	t:eq(c:getFree(), 1)
end

function test.collection_add_get(t)
	local c = MatchCollection()
	local m = Match(5, "Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	c:add(m)
	t:eq(c:get(5), m)
	t:eq(c:getFree(), 1)
end

function test.collection_remove(t)
	local c = MatchCollection()
	local m = Match(3, "Test Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	c:add(m)
	c:remove(m)
	t:eq(c:get(3), nil)
end

function test.collection_all(t)
	local c = MatchCollection()
	local m1 = Match(1, "Match1", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	local m2 = Match(5, "Match2", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	c:add(m1)
	c:add(m2)

	local all = c:all()
	t:eq(#all, 2)
end

return test
