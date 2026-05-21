local LogicNote = require("rizu.engine.logic.notes.LogicNote")

---@alias rizu.TapLogicNoteState "clear"|"missed"|"passed"

---@class rizu.TapLogicNote: rizu.LogicNote
---@operator call: rizu.TapLogicNote
local TapLogicNote = LogicNote + {}

---@param note chart.LinkedNote
---@param logic_info rizu.LogicInfo
function TapLogicNote:new(note, logic_info)
	assert(note:getType() == "tap")
	assert(note:isShort())

	LogicNote.new(self, note, logic_info)
end

---@return boolean
function TapLogicNote:isActive()
	return self.state == "clear"
end

---@param value any
function TapLogicNote:input(value)
	if not value then
		return
	end

	local result = self:getResult()

	if result == "too early" then
		self:switchState("clear")
	elseif result == "early" or result == "late" then
		self:switchState("missed")
	elseif result == "exactly" then
		self:switchState("passed")
	end
end

function TapLogicNote:update()
	local result = self:getResult()
	if result == "too late" then
		self:switchState("missed")
	end
end

---@return number
function TapLogicNote:getStartTime()
	return self.linked_note:getStartTime() + self.logic_info:getNoteMinTime("ShortNote")
end

---@return number
function TapLogicNote:getEndTime()
	return self.linked_note:getEndTime() + self.logic_info:getNoteMaxTime("ShortNote")
end

---@return sea.TimingResult
function TapLogicNote:getResult()
	local dt = self:getDeltaTime()
	return self.logic_info.timing_values:hit("ShortNote", dt)
end

---@param state rizu.TapLogicNoteState
function TapLogicNote:switchState(state)
	local old_state = self.state
	self.state = state

	local last_time = self.logic_info.timing_values:getMaxTime("ShortNote")
	local last_time_full = self:getEndTime()

	local current_time = math.min(self.logic_info.time, last_time_full)
	local delta_time = math.min(self:getDeltaTime(), last_time)

	self.logic_info:addNoteChange({
		index = self.index,
		type = "tap",
		time = current_time,
		delta_time = delta_time,
		old_state = old_state,
		new_state = state,
	})

	if not self.pressed_at and state == "passed" then
		self.pressed_at = current_time
	end
	if self.pressed_at and state ~= "passed" then
		self.pressed_at = nil
	end
end

TapLogicNote.__lt = LogicNote.__lt

return TapLogicNote
