local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local EtternaTimings = require("sea.timings.stepmania.EtternaTimings_v2")
local EtternaJudges = require("rizu.engine.ScoreEngine.scores.EtternaJudges")
local EtternaAccuracy = require("rizu.engine.ScoreEngine.scores.EtternaAccuracy")

---Etterna. Value: judge.
---@class rizu.engine.scoring.systems.Etterna : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Etterna
local Etterna = TimingSystem + {}

Etterna.name = "etternaj"
Etterna.label = "Etterna"
Etterna.normalscore = false
Etterna.grade_scale = "etternaj"
Etterna.values = {4, 5, 6, 7, 8, 9}
Etterna.default_value = 4

---@param value number
function Etterna:formatValue(value)
	return ("J%i"):format(value)
end

function Etterna:isNearest()
	return true
end

---@param timings sea.Timings
function Etterna:getName(timings)
	return ("Etterna J%i"):format(timings.data)
end

---@param timings sea.Timings
function Etterna:newTimingValues(timings)
	return EtternaTimings:getTimingValues(timings.data)
end

---@param timings sea.Timings
function Etterna:newScoreSystems(timings)
	return {EtternaJudges(timings.data), EtternaAccuracy(timings.data)}
end

function Etterna:getAccuracyClass()
	return EtternaAccuracy
end

---@param accuracy number
function Etterna:getGrade(accuracy)
	if accuracy > 0.999935 then
		return "AAAAA"
	elseif accuracy > 0.99955 then
		return "AAAA"
	elseif accuracy > 0.997 then
		return "AAA"
	elseif accuracy > 0.93 then
		return "AA"
	elseif accuracy > 0.85 then
		return "A"
	elseif accuracy > 0.8 then
		return "B"
	elseif accuracy > 0.7 then
		return "C"
	end
	return "F"
end

return Etterna()
