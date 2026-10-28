local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local LunaticRaveTimings = require("sea.timings.bmsrank.LunaticRaveTimings_v2")
local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")

---Lunatic Rave 2. Value: #RANK.
---@class rizu.engine.scoring.systems.LunaticRave : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.LunaticRave
local LunaticRave = TimingSystem + {}

LunaticRave.name = "bmsrank"
LunaticRave.healths_name = "lr2"
LunaticRave.label = "LR2"
LunaticRave.normalscore = false
LunaticRave.grade_scale = "bmsrank"
LunaticRave.values = {3, 2, 1, 0, 4}
LunaticRave.default_value = 3

local rank_names = {
	[0] = "Insane",
	[1] = "Hard",
	[2] = "Normal",
	[3] = "Easy",
	[4] = "Invalid",
}

---@param value number
function LunaticRave:formatValue(value)
	return assert(rank_names[value], "unknown LR2 timing rank")
end

---@param timings sea.Timings
function LunaticRave:getName(timings)
	return ("LR2 %s"):format(rank_names[timings.data])
end

function LunaticRave:newTimingValues()
	return LunaticRaveTimings:getTimingValues()
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param healths sea.Healths? Other kinds than lr2 mean the groove gauge.
function LunaticRave:newScoreSystems(timings, subtimings, healths)
	local gauge = healths and healths.name == "lr2" and healths.data or nil
	return {LunaticRaveScore(timings.data, gauge)}
end

function LunaticRave:getAccuracyClass()
	return LunaticRaveScore
end

---EX score ranks: accuracy is EX score over its maximum.
---@param accuracy number
function LunaticRave:getGrade(accuracy)
	local rank = math.floor(accuracy * 9)
	if rank >= 8 then
		return "AAA"
	elseif rank == 7 then
		return "AA"
	elseif rank == 6 then
		return "A"
	elseif rank == 5 then
		return "B"
	elseif rank == 4 then
		return "C"
	elseif rank == 3 then
		return "D"
	elseif rank == 2 then
		return "E"
	end
	return "F"
end

return LunaticRave()
