local LogicNote = require("rizu.engine.logic.notes.LogicNote")

---@class rizu.SimpleLogicNote: rizu.LogicNote
---@operator call: rizu.SimpleLogicNote
local SimpleLogicNote = LogicNote + {}

function SimpleLogicNote:new(note, logic_info)
	LogicNote.new(self, note, logic_info)
end

function SimpleLogicNote:isActive()
	return self.state == "clear"
end

function SimpleLogicNote:isPlayable() return false end

function SimpleLogicNote:input(value)
	-- No input processing
end

function SimpleLogicNote:update()
	if self.logic_info:sub(self.linked_note:getStartTime()) >= 0 then
		self:switchState("passed")
	end
end

function SimpleLogicNote:getStartTime()
	return self.linked_note:getStartTime()
end

function SimpleLogicNote:getEndTime()
	return self.linked_note:getEndTime()
end

---@param state string
function SimpleLogicNote:switchState(state)
	self.state = state
end

SimpleLogicNote.__lt = LogicNote.__lt

return SimpleLogicNote
