local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local QuaverTimings = require("sea.timings.quaver.QuaverTimings_v1")
local QuaverScore = require("rizu.engine.ScoreEngine.scores.QuaverScore")

---Quaver's standard windows.
---@class rizu.engine.scoring.systems.Quaver : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Quaver
local Quaver = TimingSystem + {}

Quaver.name = "quaver"
Quaver.label = "Quaver"
Quaver.normalscore = false
Quaver.grade_scale = "quaver"

function Quaver:getName()
	return "Quaver standard"
end

function Quaver:newTimingValues()
	return QuaverTimings:getTimingValues()
end

function Quaver:newScoreSystems()
	return {QuaverScore()}
end

function Quaver:getAccuracyClass()
	return QuaverScore
end

---@param accuracy number
function Quaver:getGrade(accuracy)
	if accuracy == 1 then
		return "X"
	elseif accuracy > 0.99 then
		return "SS"
	elseif accuracy > 0.95 then
		return "S"
	elseif accuracy > 0.9 then
		return "A"
	elseif accuracy > 0.8 then
		return "B"
	elseif accuracy > 0.7 then
		return "C"
	elseif accuracy > 0.6 then
		return "D"
	end
	return "F"
end

return Quaver()
