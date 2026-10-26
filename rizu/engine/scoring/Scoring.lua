local class = require("class")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---How a play is judged and scored: a sea.Timings with its sea.Subtimings, missing ones filled with
---the system's default, so equal scorings have equal keys. Names, accuracy text and grades come from here.
---@class rizu.engine.scoring.Scoring
---@operator call: rizu.engine.scoring.Scoring
---@field timings sea.Timings
---@field subtimings sea.Subtimings?
---@field healths sea.Healths? Nil is the default of the system.
---@field system rizu.engine.scoring.TimingSystem
local Scoring = class()

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param healths sea.Healths?
function Scoring:new(timings, subtimings, healths)
	self.system = TimingSystems.get(timings.name)
	self.timings = timings
	self.healths = healths
	self.subtimings = subtimings or self.system.default_subtimings
end

---@return string
function Scoring:getName()
	return self.system:getName(self.timings, self.subtimings)
end

---@return sea.TimingValues?
---@return string?
function Scoring:getTimingValues()
	return self.system:getTimingValues(self.timings, self.subtimings)
end

---@return rizu.ScoreSystem[]?
---@return string?
function Scoring:createScoreSystems()
	return self.system:createScoreSystems(self.timings, self.subtimings, self.healths)
end

---A press hits the nearest note instead of the earliest one.
---@return boolean
function Scoring:isNearest()
	return self.system:isNearest(self.subtimings)
end

---Its accuracy is normalscore's: the mean error in seconds, lower is better. Otherwise 0..1, higher is better.
---@return boolean
function Scoring:isNormalscore()
	return self.system.normalscore
end

---@param accuracy number
---@return string text Such as "98.50%" or "21.00ms".
function Scoring:formatAccuracy(accuracy)
	local class_ = self.system:getAccuracyClass(self.subtimings)
	return class_.accuracy_format:format(accuracy * class_.accuracy_multiplier)
end

---@param accuracy number
---@return string
function Scoring:getGrade(accuracy)
	return self.system:getGrade(accuracy)
end

---@return integer timings
---@return integer subtimings 0 for none.
function Scoring:encode()
	return self.timings:encode(), self.subtimings and self.subtimings:encode() or 0
end

---The score system of the engine that counts this scoring's accuracy, added to it when missing.
---@param score_engine rizu.ScoreEngine
---@return rizu.IAccuracySource?
function Scoring:getAccuracySource(score_engine)
	if self:isNormalscore() then
		return score_engine.scores.normalscore
	end
	for _, system in ipairs(self:createScoreSystems() or {}) do
		if IAccuracySource * system then
			return score_engine:addScoreSystem(system) --[[@as rizu.IAccuracySource]]
		end
	end
end

return Scoring
