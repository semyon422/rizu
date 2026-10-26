local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")

---Default healths: starts half full, a hit gives 1, a miss takes a 20th of the bar, empty stays empty.
---@class rizu.HpScore: rizu.ScoreSystem, rizu.IHealthsSource
---@operator call: rizu.HpScore
---@field value number
local HpScore = ScoreSystem + IHealthsSource

HpScore.max = 1000

-- Misses in a row that empty a full bar.
local misses_to_fail = 20

function HpScore:new()
	self.value = self.max / 2
end

---@return string
function HpScore:getKey()
	return "hp"
end

---@return rizu.HpScore.Slice
function HpScore:getSlice()
	---@class rizu.HpScore.Slice
	---@field healths number
	---@field max_healths number
	local t = {
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
	}
	return t
end

---@return number
function HpScore:getHealths()
	return self.value
end

---@return number
function HpScore:getMaxHealths()
	return self.max
end

---@return boolean
function HpScore:isFailed()
	return self.value <= 0
end

---@param event rizu.LogicNoteChange
function HpScore:increase(event)
	if not self:isFailed() then
		self.value = math.min(self.value + 1, self.max)
	end
end

---@param event rizu.LogicNoteChange
function HpScore:decrease(event)
	if self:isFailed() then
		return
	end
	self.value = self.value - self.max / misses_to_fail
	if self.value < 1e-3 then
		self.value = 0
	end
end

HpScore.events = {
	tap = {
		clear = {
			passed = "increase",
			missed = "decrease",
			clear = nil,
		},
	},
	hold = {
		clear = {
			startPassedPressed = "increase",
			startMissed = "decrease",
			startMissedPressed = "decrease",
			clear = nil,
		},
		startPassedPressed = {
			startMissed = nil,
			endMissed = "decrease",
			endPassed = "increase",
		},
		startMissedPressed = {
			endMissedPassed = "increase",
			startMissed = nil,
			endMissed = "decrease",
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = "decrease",
		},
	},
}

return HpScore
