local LogicalNote = require("sphere.models.RhythmModel.LogicEngine.LogicalNote")

---@class sphere.LongLogicalNote: sphere.LogicalNote
---@operator call: sphere.LongLogicalNote
local LongLogicalNote = LogicalNote + {}

---@param note chart.LinkedNote
---@param isPlayable boolean?
---@param isScorable boolean?
---@param isInputMatchable boolean?
function LongLogicalNote:new(note, isPlayable, isScorable, isInputMatchable)
	self.startNote = note.startNote
	self.endNote = note.endNote
	self.isPlayable = isPlayable
	self.isScorable = isScorable
	self.isInputMatchable = isInputMatchable
	self.state = "clear"
end

function LongLogicalNote:update()
	if self.ended then
		return
	end

	if not self.isPlayable or self.logicEngine.autoplay then
		self:processAuto()
		return
	end

	local startTimeState = self:getStartTimeState()
	local endTimeState = self:getEndTimeState()
	self:processTimeState(startTimeState, endTimeState)
end

---@param startTimeState string
---@param endTimeState string
function LongLogicalNote:processTimeState(startTimeState, endTimeState)
	if self.isInputMatchable and not self.inputMatched then
		self.keyState = false
	end

	local lastState = self.state

	local keyState = self.keyState
	if keyState and startTimeState == "too early" then
		self:switchState("clear")
		self.keyState = false
	elseif lastState == "clear" then
		if startTimeState == "too late" then
			self:switchState("startMissed")
			self:tryNextNote()
			if self.state == "startMissed" and endTimeState == "too late" then
				self:switchState("endMissed")
				self:next()
				return
			end
		elseif keyState then
			if startTimeState == "early" or startTimeState == "late" then
				self:switchState("startMissedPressed")
			elseif startTimeState == "exactly" then
				self:switchState("startPassedPressed")
			end
		end
	elseif lastState == "startPassedPressed" then
		if endTimeState == "too late" then
			self:switchState("endMissed")
			self:next()
			return
		elseif not keyState then
			if endTimeState == "too early" then
				self:switchState("startMissed")
			elseif endTimeState == "early" or endTimeState == "late" then
				self:switchState("endMissed")
				self:next()
				return
			elseif endTimeState == "exactly" then
				self:switchState("endPassed")
				self:next()
				return
			end
		end
	elseif lastState == "startMissedPressed" then
		if not keyState then
			if endTimeState == "too early" then
				self:switchState("startMissed")
			elseif endTimeState == "early" or endTimeState == "late" then
				self:switchState("endMissed")
				self:next()
				return
			elseif endTimeState == "exactly" then
				self:switchState("endMissedPassed")
				self:next()
				return
			end
		elseif endTimeState == "too late" then
			self:switchState("endMissed")
			self:next()
			return
		end
	elseif lastState == "startMissed" then
		if keyState then
			self:switchState("startMissedPressed")
		elseif endTimeState == "too late" then
			self:switchState("endMissed")
			self:next()
			return
		end
	end

	self:tryNextNote()
end

function LongLogicalNote:tryNextNote()
	local nextNote = self:getNextPlayable()
	if not nextNote or self.state ~= "startMissed" then
		return
	end

	if not nextNote:isReachable(self:getEventTime()) then
		return
	end

	self:switchState("endMissed", nextNote)
	self:next()
end

---@param side string?
---@return number
function LongLogicalNote:getNoteTime(side)
	local offset = 0
	if self.isPlayable then
		offset = self.logicEngine:getInputOffset()
	end
	if not side or side == "start" then
		return self.startNote:getTime() + offset
	elseif side == "end" then
		return self.endNote:getTime() + offset
	end
	error("Wrong side")
end

---@param side string?
---@return number
function LongLogicalNote:getDeltaTime(side)
	local offset = 0
	if self.isPlayable then
		offset = self.logicEngine:getInputOffset()
	end
	local eventTime = self:getEventTime() - offset
	if not side or side == "start" then
		return eventTime - self.startNote:getTime()
	elseif side == "end" then
		return eventTime - self.endNote:getTime()
	end
	error("Wrong side")
end

---@param newState string
---@param reachableNote sphere.LogicalNote?
function LongLogicalNote:switchState(newState, reachableNote)
	local oldState = self.state
	self.state = newState

	if not self.isScorable then
		return
	end

	local timings = self.logicEngine.timings

	local currentTime, deltaTime
	local eventTime = self:getEventTime()
	local timeRate = self.logicEngine:getTimeRate()
	if oldState == "clear" then
		local noteTime = self:getNoteTime("start")
		local lastTime = self:getLastTimeFromConfig(timings.LongNoteStart)
		local time = noteTime + lastTime * timeRate

		currentTime = math.min(eventTime, time)
		deltaTime = math.min(self:getDeltaTime("start") / timeRate, lastTime)
	else
		local noteTime = self:getNoteTime("end")
		local lastTime = self:getLastTimeFromConfig(timings.LongNoteEnd)
		local time = noteTime + lastTime * timeRate

		currentTime = math.min(eventTime, time)
		deltaTime = math.min(self:getDeltaTime("end") / timeRate, lastTime)
	end

	if reachableNote then
		local time = reachableNote:getNoteTime("start") + self:getFirstTimeFromConfig(timings.ShortNote) * timeRate
		currentTime = math.min(currentTime, time)
		deltaTime = self:getLastTimeFromConfig(timings.LongNoteEnd)
	end

	local scoreEvent = {
		name = "NoteState",
		noteType = "LongNote",
	}

	scoreEvent.noteIndex = self.index
	scoreEvent.noteIndexType = self.index .. self.column -- required for osu!legacy LN's to track their state
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

	if not self.pressedTime and (newState == "startPassedPressed" or newState == "startMissedPressed") then
		self.pressedTime = currentTime
	end
	if self.pressedTime and newState ~= "startPassedPressed" and newState ~= "startMissedPressed" then
		self.pressedTime = nil
	end
end

function LongLogicalNote:processAuto()
	local deltaStartTime = self:getDeltaTime("start")
	local deltaEndTime = self:getDeltaTime("end")

	local nextNote = self:getNextPlayable()
	if deltaStartTime >= 0 and not self.keyState then
		self.keyState = true
		self.inputMatched = true
		self.logicEngine:playSound(self.startNote, not self.isPlayable)

		self.eventTime = self:getNoteTime("start")
		self:processTimeState("exactly", "too early")
		self.eventTime = nil
	end
	if deltaEndTime >= 0 and self.keyState or nextNote and nextNote:isHere() then
		self.keyState = false
		self.logicEngine:playSound(self.endNote, not self.isPlayable)

		self.eventTime = self:getNoteTime("end")
		self:processTimeState("too late", "exactly")
		self.eventTime = nil
	end
end

---@return string
function LongLogicalNote:getStartTimeState()
	local deltaTime = self:getDeltaTime("start") / self.logicEngine:getTimeRate()
	return self:getTimeStateFromConfig(self.logicEngine.timings.LongNoteStart, deltaTime)
end

---@return string
function LongLogicalNote:getEndTimeState()
	local deltaTime = self:getDeltaTime("end") / self.logicEngine:getTimeRate()
	return self:getTimeStateFromConfig(self.logicEngine.timings.LongNoteEnd, deltaTime)
end

---@param _eventTime number
---@return boolean
function LongLogicalNote:isReachable(_eventTime)
	local eventTime = self.eventTime
	self.eventTime = _eventTime
	local isReachable = self:getStartTimeState() ~= "too early"
	self.eventTime = eventTime
	return isReachable
end

return LongLogicalNote
