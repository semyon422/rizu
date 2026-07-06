local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local RingBuffer = require("RingBuffer")

---@class rizu.BaseScore: rizu.ScoreSystem, rizu.IComboSource
---@operator call: rizu.BaseScore
local BaseScore = ScoreSystem + IComboSource

function BaseScore:new()
	self.meanRingBuffer = RingBuffer(10)

	self.hitCount = 0
	self.missCount = 0
	self.earlyHitCount = 0

	self.combo = 0
	self.maxCombo = 0
	self.currentTime = 0

	self.isMiss = false
	self.isEarlyHit = false
	self.isLongNoteComboBreak = false

	self.lastMean = 0
end

---@return string
function BaseScore:getKey()
	return "base"
end

---@return integer
function BaseScore:getCombo()
	return self.combo
end

---@return integer
function BaseScore:getMaxCombo()
	return self.maxCombo
end

---@param event rizu.LogicNoteChange
function BaseScore:before(event)
	self.currentTime = event.time
	self.isMiss = false
	self.isEarlyHit = false
	self.isLongNoteComboBreak = false
end

---@param event rizu.LogicNoteChange
function BaseScore:success(event)
	self.hitCount = self.hitCount + 1
	self.combo = self.combo + 1
	self.maxCombo = math.max(self.maxCombo, self.combo)
end

---@param event rizu.LogicNoteChange
function BaseScore:breakCombo(event)
	self.combo = 0
end

---@param event rizu.LogicNoteChange
function BaseScore:breakComboLongNote(event)
	self.combo = 0
	self.isLongNoteComboBreak = true
end

---@param event rizu.LogicNoteChange
function BaseScore:miss(event)
	self.missCount = self.missCount + 1
	self.isMiss = true
end

---@param event rizu.LogicNoteChange
function BaseScore:earlyHit(event)
	self.earlyHitCount = self.earlyHitCount + 1
	self.isEarlyHit = true
end

---@param event rizu.LogicNoteChange
function BaseScore:countLastMean(event)
	local rb = self.meanRingBuffer
	rb:write(event.delta_time)
	local sum = 0
	for i = 1, rb.size do
		---@type number
		sum = sum + rb:read()
	end
	self.lastMean = sum / rb.size
end

---@return rizu.BaseScore.Slice
function BaseScore:getSlice()
	---@class rizu.BaseScore.Slice
	local t = {
		hitCount = self.hitCount,
		missCount = self.missCount,
		earlyHitCount = self.earlyHitCount,
		notesCount = self.notes_count,
		combo = self.combo,
		maxCombo = self.maxCombo,
		currentTime = self.currentTime,
		isMiss = self.isMiss,
		isEarlyHit = self.isEarlyHit,
		isLongNoteComboBreak = self.isLongNoteComboBreak,
	}
	return t
end

BaseScore.events = {
	tap = {
		clear = {
			passed = {"success", "countLastMean"},
			missed = {"breakCombo", "miss"},
			clear = "earlyHit",
		},
	},
	hold = {
		clear = {
			startPassedPressed = "countLastMean",
			startMissed = "breakComboLongNote",
			startMissedPressed = "breakComboLongNote",
			clear = "earlyHit",
		},
		startPassedPressed = {
			startMissed = "breakComboLongNote",
			endMissed = {"breakComboLongNote", "miss"},
			endPassed = {"success", "countLastMean"},
		},
		startMissedPressed = {
			endMissedPassed = {"success", "countLastMean"},
			startMissed = "breakComboLongNote",
			endMissed = {"breakComboLongNote", "miss"},
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = {"breakComboLongNote", "miss"},
		},
	},
}

return BaseScore
