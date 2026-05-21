local LogicalNote = require("sphere.models.RhythmModel.LogicEngine.LogicalNote")

---@class sphere.ShortLogicalNote: sphere.LogicalNote
---@operator call: sphere.ShortLogicalNote
local ShortLogicalNote = LogicalNote + {}

---@param note chart.LinkedNote
---@param isPlayable boolean?
---@param isScorable boolean?
---@param isInputMatchable boolean?
function ShortLogicalNote:new(note, isPlayable, isScorable, isInputMatchable)
	self.startNote = note.startNote
	self.isPlayable = isPlayable
	self.isScorable = isScorable
	self.isInputMatchable = isInputMatchable
	self.state = "clear"
end

function ShortLogicalNote:update()
	if self.ended then
		return
	end

	if not self.isPlayable or self.logicEngine.autoplay then
		return self:processAuto()
	end

	local timeState = self:getTimeState()
	self:processTimeState(timeState)
end

---@param timeState string
function ShortLogicalNote:processTimeState(timeState)
	if self.isInputMatchable and not self.inputMatched then
		self.keyState = false
	end
	local keyState = self.keyState
	if keyState and timeState == "too early" then
		self:switchState("clear")
		self.keyState = false
	elseif keyState and (timeState == "early" or timeState == "late") or timeState == "too late" then
		self:switchState("missed")
		self:next()
	elseif keyState and timeState == "exactly" then
		self:switchState("passed")
		self:next()
	end
end

---@param newState string
function ShortLogicalNote:switchState(newState)
	local oldState = self.state
	self.state = newState

	if not self.isScorable then
		return
	end

	local timings = self.logicEngine.timings
	local timeRate = self.logicEngine:getTimeRate()
	local eventTime = self:getEventTime()
	local noteTime = self:getNoteTime()

	local lastTime = self:getLastTimeFromConfig(timings.ShortNote)
	local time = noteTime + lastTime * timeRate

	local currentTime = math.min(eventTime, time)
	local deltaTime = math.min(self:getDeltaTime() / timeRate, lastTime)

	local scoreEvent = {
		name = "NoteState",
		noteType = "ShortNote",
	}

	scoreEvent.noteIndex = self.index  -- required for tests
	scoreEvent.currentTime = currentTime
	scoreEvent.noteStartTime = self.startNote:getTime()
	scoreEvent.noteColumn = self.startNote.column
	scoreEvent.inputOffset = self.logicEngine.inputOffset
	scoreEvent.selfEventTime = self.eventTime
	scoreEvent.engineEventTime = self.logicEngine:getEventTime()
	scoreEvent.deltaTime = deltaTime
	scoreEvent.timeRate = timeRate
	scoreEvent.notesCount = self.logicEngine.notesCount
	scoreEvent.oldState = oldState
	scoreEvent.newState = newState
	self.logicEngine:sendScore(scoreEvent)

	if not self.pressedTime and newState == "passed" then
		self.pressedTime = currentTime
	end
	if self.pressedTime and newState ~= "passed" then
		self.pressedTime = nil
	end
end

function ShortLogicalNote:processAuto()
	if not self:isHere() then
		return
	end

	self.keyState = true
	self.inputMatched = true  -- need for promode
	self.logicEngine:playSound(self.startNote, not self.isPlayable)

	self.eventTime = self:getNoteTime()
	self:processTimeState("exactly")
	self.eventTime = nil
end

---@return string
function ShortLogicalNote:getTimeState()
	local deltaTime = self:getDeltaTime() / self.logicEngine:getTimeRate()
	return self:getTimeStateFromConfig(self.logicEngine.timings.ShortNote, deltaTime)
end

---@param _eventTime number
---@return boolean
function ShortLogicalNote:isReachable(_eventTime)
	local eventTime = self.eventTime
	self.eventTime = _eventTime
	local isReachable = self:getTimeState() ~= "too early"
	self.eventTime = eventTime
	return isReachable
end

return ShortLogicalNote
