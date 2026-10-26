--- SOURCE: https://github.com/etternagame/etterna
--- SOURCE: https://github.com/etternagame/etterna/blob/master/Themes/_fallback/Scripts/10%20Scores.lua

local erfunc = require("chart.scoring.erfunc")
local math_util = require("math_util")
local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local EtternaJudges = require("rizu.engine.ScoreEngine.scores.EtternaJudges")
local Timings = require("sea.chart.Timings")

---@class rizu.EtternaAccuracy: rizu.ScoreSystem, rizu.IAccuracySource, rizu.IHealthsSource
---@operator call: rizu.EtternaAccuracy
local EtternaAccuracy = ScoreSystem + IAccuracySource + IHealthsSource

EtternaAccuracy.accuracy_multiplier = 100
EtternaAccuracy.accuracy_format = "%0.02f%%"

local judgeDifficulty = {0, 0, 0, 1.00, 0.84, 0.66, 0.50, 0.33, 0.20}

-- LifeDifficulty levels L1..L7 of Etterna, scale of the life gained, the life lost is divided by it.
local lifeScales = {1.6, 1.4, 1.2, 1.0, 0.8, 0.6, 0.4}
EtternaAccuracy.default_life_level = 4

-- Life change by judge index: marvelous, perfect, great, bad, boo, then a miss. LifePercentChange* of metrics.ini.
local lifeChanges = {0.008, 0.008, 0.004, 0, -0.04, -0.08}
local lifeHeld = 0.008
local lifeLetGo = -0.08

---@param j integer
---@param life_level integer? Etterna LifeDifficulty 1..7.
function EtternaAccuracy:new(j, life_level)
	self.timings = Timings("etternaj", j)
	self.judge_windows = JudgeWindows(EtternaJudges.windows[j])

	self.life_level = life_level or self.default_life_level
	self.life_scale = lifeScales[self.life_level]
	self.life = 0.5

	self.judge = j

	self.difficulty = judgeDifficulty[j]

	self.maxPoints = 2
	self.missWeight = -5.5
	self.holdDropWeight = -4.5
	self.jPow = 0.75
	self.maxBooWeight = 0.180 * self.difficulty
	self.ridic = 0.005 * self.difficulty

	self.points = 0
	self.miss_count = 0
	self.notes = 0
	self.holds_held = 0
	self.holds_let_go = 0
	self.holds_missed = 0
end

---@return string
function EtternaAccuracy:getKey()
	local key = "etterna_accuracy_j" .. self.judge
	if self.life_level ~= self.default_life_level then
		key = key .. "_l" .. self.life_level
	end
	return key
end

---@param delta number
function EtternaAccuracy:changeLife(delta)
	if self.life <= 0 then
		return
	end
	delta = delta > 0 and delta * self.life_scale or delta / self.life_scale
	self.life = math.min(math.max(self.life + delta, 0), 1)
end

---@return number
function EtternaAccuracy:getHealths()
	return self.life
end

---@return number
function EtternaAccuracy:getMaxHealths()
	return 1
end

---@return boolean
function EtternaAccuracy:isFailed()
	return self.life <= 0
end

---@param x number
---@return number
local function pointsMultiplier(x)
	return math_util.sign(x) * erfunc.erf(math.abs(x))
end

---@param deltaTime number
---@return number
function EtternaAccuracy:getPoints(deltaTime)
	if deltaTime <= self.ridic then
		return self.maxPoints
	end

	local zero = 0.065 * math.pow(self.difficulty, self.jPow)
	local dev = 0.0227 * math.pow(self.difficulty, self.jPow)

	if deltaTime <= zero then
		return self.maxPoints * pointsMultiplier((zero - deltaTime) / dev)
	end

	if deltaTime <= self.maxBooWeight then
		return (deltaTime - zero) * self.missWeight / (self.maxBooWeight - zero)
	end

	return self.missWeight
end

---@param event rizu.LogicNoteChange
function EtternaAccuracy:hit(event)
	self.points = self.points + self:getPoints(math.abs(event.delta_time))
	self.notes = self.notes + 1
	self:changeLife(lifeChanges[self.judge_windows:get(event.delta_time) or 6])
end

function EtternaAccuracy:miss()
	self.points = self.points + self:getPoints(math.huge)
	self.notes = self.notes + 1
	self:changeLife(lifeChanges[6])
end

-- Wife3 scores a hold head as a tap. A completed hold adds no points, while
-- a dropped or fully missed hold applies this fixed penalty; tail timing is
-- not evaluated by the Wife3 curve.
function EtternaAccuracy:holdHeld()
	self.holds_held = self.holds_held + 1
	self:changeLife(lifeHeld)
end

function EtternaAccuracy:holdLetGo()
	self.holds_let_go = self.holds_let_go + 1
	self.points = self.points + self.holdDropWeight
	self:changeLife(lifeLetGo)
end

function EtternaAccuracy:holdMissed()
	self.holds_missed = self.holds_missed + 1
	self.points = self.points + self.holdDropWeight
end

function EtternaAccuracy:getAccuracy()
	return math.max(self.points / (self.notes * self.maxPoints), 0)
end

function EtternaAccuracy:getAccuracyString()
	return ("%0.02f%%"):format(self:getAccuracy() * self.accuracy_multiplier)
end

function EtternaAccuracy:getSlice()
	return {
		accuracy = self:getAccuracy(),
		healths = self.life,
		max_healths = 1,
		holds_held = self.holds_held,
		holds_let_go = self.holds_let_go,
		holds_missed = self.holds_missed,
	}
end

EtternaAccuracy.events = {
	tap = {
		clear = {
			passed = "hit",
			missed = "miss",
			clear = nil,
		},
	},
	hold = {
		clear = {
			startPassedPressed = "hit",
			startMissed = "miss",
			startMissedPressed = nil,
			clear = nil,
		},
		startPassedPressed = {
			startMissed = nil,
			endMissed = "holdLetGo",
			endPassed = "holdHeld",
		},
		startMissedPressed = {
			endMissedPassed = "holdMissed",
			startMissed = nil,
			endMissed = "holdMissed",
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = "holdMissed",
		},
	},
}

return EtternaAccuracy
