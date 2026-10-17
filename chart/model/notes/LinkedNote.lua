local class = require("class")

---@class chart.LinkedNote
---@operator call: chart.LinkedNote
local LinkedNote = class()

---@param startNote chart.Note
---@param endNote chart.Note?
function LinkedNote:new(startNote, endNote)
	self.startNote = startNote
	self.endNote = endNote
end

function LinkedNote:clone()
	local note = setmetatable({}, LinkedNote)
	note.startNote = self.startNote:clone()
	note.endNote = self.endNote and self.endNote:clone()
	return note
end

function LinkedNote:isShort()
	return self.endNote == nil
end

function LinkedNote:isLong()
	return self.endNote ~= nil
end

function LinkedNote:unlink()
	self.startNote.weight = 0
	if self.endNote then
		self.endNote.weight = 0
		self.endNote = nil
	end
end

---@return chart.Column
function LinkedNote:getColumn()
	return self.startNote.column
end

---@return number
function LinkedNote:getStartTime()
	return self.startNote:getTime()
end

---@return number
function LinkedNote:getEndTime()
	local n = self.endNote or self.startNote
	return n:getTime()
end

---@return number
function LinkedNote:getDuration()
	if not self.endNote then
		return 0
	end
	return self.endNote:getTime() - self.startNote:getTime()
end

---@param column chart.Column
function LinkedNote:setColumn(column)
	self.startNote.column = column
	if self.endNote then
		self.endNote.column = column
	end
end

function LinkedNote:getType()
	return self.startNote.type
end

---@param _type string
function LinkedNote:setType(_type)
	self.startNote.type = _type
	if self.endNote then
		self.endNote.type = _type
	end
end

---@param a chart.LinkedNote
---@param b chart.LinkedNote
---@return boolean
function LinkedNote.__lt(a, b)
	return a.startNote < b.startNote
end

return LinkedNote
