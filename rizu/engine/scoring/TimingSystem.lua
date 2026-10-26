local class = require("class")
local SoundsphereScore = require("rizu.engine.ScoreEngine.scores.SoundsphereScore")

---Everything the game knows about one kind of sea.Timings: its hit windows, the score systems that
---count it, and how its accuracy, grades and name are written. One instance per timings name, see
---rizu.engine.scoring.TimingSystems. The methods take the sea.Timings and sea.Subtimings of a play.
---@class rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.TimingSystem
---@field name sea.TimingsName
---@field label string "osu!mania", without the value.
---@field normalscore boolean Its accuracy is normalscore's: the mean error in seconds, lower is better.
---@field grade_scale string Systems with the same scale give the same grades.
---@field default_subtimings sea.Subtimings? What missing subtimings mean.
---@field values number[]? The values a picker offers, nil for a range or no value.
---@field range {min: number, max: number, step: number}? The values a slider offers.
---@field default_value number? For systems that take a value.
---@field score_versions integer[]? The scorev subtimings a player can pick, for osu!mania.
local TimingSystem = class()

TimingSystem.normalscore = true
TimingSystem.grade_scale = "sphere"

local err_msg = "invalid timings-subtimings pair"

---@param value number
---@return string
function TimingSystem:formatValue(value)
	return ("%g"):format(value)
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@return string
function TimingSystem:getName(timings, subtimings)
	return self.label
end

---A press hits the nearest note instead of the earliest one.
---@param subtimings sea.Subtimings?
---@return boolean
function TimingSystem:isNearest(subtimings)
	return false
end

---@param subtimings sea.Subtimings?
---@return boolean
function TimingSystem:acceptsSubtimings(subtimings)
	return subtimings == nil
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@return sea.TimingValues?
---@return string?
function TimingSystem:getTimingValues(timings, subtimings)
	if not self:acceptsSubtimings(subtimings) then
		return nil, err_msg
	end
	return self:newTimingValues(timings, subtimings or self.default_subtimings)
end

---@protected
---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@return sea.TimingValues?
---@return string?
function TimingSystem:newTimingValues(timings, subtimings)
	error("not implemented")
end

---The score systems that count a play, besides the ones every play has (see rizu.ScoreEngine).
---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param healths sea.Healths?
---@return rizu.ScoreSystem[]?
---@return string?
function TimingSystem:createScoreSystems(timings, subtimings, healths)
	if not self:acceptsSubtimings(subtimings) then
		return nil, err_msg
	end
	return self:newScoreSystems(timings, subtimings or self.default_subtimings, healths)
end

---@protected
---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param healths sea.Healths?
---@return rizu.ScoreSystem[]?
---@return string?
function TimingSystem:newScoreSystems(timings, subtimings, healths)
	return nil, "not implemented"
end

---The score system class whose accuracy_format and accuracy_multiplier write the accuracy.
---@param subtimings sea.Subtimings?
---@return rizu.IAccuracySource
function TimingSystem:getAccuracyClass(subtimings)
	return SoundsphereScore
end

---@param accuracy number
---@return string
function TimingSystem:getGrade(accuracy)
	if accuracy < 0.002 then
		return "SSSSS"
	elseif accuracy < 0.003 then
		return "SSSS"
	elseif accuracy < 0.005 then
		return "SSS"
	elseif accuracy < 0.008 then
		return "SS"
	elseif accuracy < 0.016 then
		return "S"
	elseif accuracy < 0.022 then
		return "A"
	elseif accuracy < 0.026 then
		return "B"
	elseif accuracy < 0.030 then
		return "C"
	end
	return "D"
end

return TimingSystem
