local class = require("class")

---@alias rizu.LogicNoteState "clear"|"missed"|"passed"

---@class rizu.LogicNote
---@operator call: rizu.LogicNote
local LogicNote = class()

LogicNote.index = 0

---@param note chart.LinkedNote
---@param logic_info rizu.LogicInfo
function LogicNote:new(note, logic_info)
	self.linked_note = note
	self.logic_info = logic_info

	self:reset()
end

function LogicNote:reset()
	self.state = "clear"
end

---@return boolean
function LogicNote:isActive()
	error("not implemented")
end

---@return boolean
function LogicNote:isPlayable()
	return true
end

---@return boolean
function LogicNote:isEarly()
	return self.logic_info:sub(self:getStartTime()) < 0
end

---@param value any
function LogicNote:input(value)
	error("not implemented")
end

function LogicNote:update()
	error("not implemented")
end

---@return chart.Column
function LogicNote:getColumn()
	return self.linked_note:getColumn()
end

---@return number
function LogicNote:getDeltaTime()
	return self.logic_info:sub(self.linked_note:getStartTime())
end

---@return number
function LogicNote:getStartTime()
	error("not implemented")
end

---@return number
function LogicNote:getEndTime()
	error("not implemented")
end

---@param state string
function LogicNote:switchState(state)
	error("not implemented")
end

---@param a rizu.LogicNote
---@param b rizu.LogicNote
---@return boolean
function LogicNote.__lt(a, b)
	return a.linked_note < b.linked_note
end

return LogicNote
