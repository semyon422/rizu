local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local LunaticRave = require("rizu.engine.scoring.systems.LunaticRave")
local IidxTimings = require("sea.timings.iidx.IidxTimings_v1")
local IidxScore = require("rizu.engine.ScoreEngine.scores.IidxScore")

---beatmania IIDX.
---@class rizu.engine.scoring.systems.Iidx : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Iidx
local Iidx = TimingSystem + {}

Iidx.name = "iidx"
Iidx.healths_name = "iidx"
Iidx.label = "IIDX"
Iidx.normalscore = false
Iidx.grade_scale = "iidx"

function Iidx:newTimingValues()
	return IidxTimings:getTimingValues()
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param healths sea.Healths? Other kinds than iidx mean the normal gauge.
function Iidx:newScoreSystems(timings, subtimings, healths)
	local gauge = healths and healths.name == "iidx" and healths.data or nil
	return {IidxScore(gauge)}
end

function Iidx:getAccuracyClass()
	return IidxScore
end

-- The same EX score ranks as LR2.
Iidx.getGrade = LunaticRave.getGrade

return Iidx()
