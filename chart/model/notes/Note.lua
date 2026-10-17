local class = require("class")
local valid = require("valid")
local table_util = require("table_util")

---@alias chart.NoteType string

---@class chart.Note
---@operator call: chart.Note
---@field startNote chart.Note?
---@field endNote chart.Note?
local Note = class()

Note.weight = 0

---@param visualPoint chart.IVisualPoint
---@param column chart.Column
---@param _type chart.NoteType
---@param weight integer
---@param data table
function Note:new(visualPoint, column, _type, weight, data)
	self.visualPoint = assert(visualPoint, "missing visualPoint")
	self.column = assert(column, "missing column")
	self.type = _type
	self.weight = weight
	self.data = data or {}
end

---@return chart.Note
function Note:clone()
	local note = setmetatable({}, Note)
	table_util.copy(self, note)
	return note
end

---@return number
function Note:getTime()
	return self.visualPoint.point.absoluteTime
end

---@param vp chart.IVisualPoint?
---@return number
function Note:getVisualTime(vp)
	return self.visualPoint:getVisualTime(vp)
end

---@return number
function Note:getBeatModulo()
	local b = self.visualPoint.point:getBeatModulo()
	if type(b) == "number" then
		return b
	end
	return b:tonumber()
end

---@return number
function Note:getBeatDuration()
	return self.visualPoint.point:getBeatDuration()
end

---@param a chart.Note
---@return string
function Note.__tostring(a)
	return ("Note(%s,%s,%s,%s)"):format(a.visualPoint, a.column, a.type, a.weight)
end

---@param a chart.Note
---@param b chart.Note
---@return boolean
function Note.__eq(a, b)
	return a.visualPoint == b.visualPoint and a.column == b.column
end

---@param a chart.Note
---@param b chart.Note
---@return boolean
function Note.__lt(a, b)
	return a.visualPoint < b.visualPoint or a.visualPoint == b.visualPoint and a.column < b.column
end

local validate_note = valid.struct({
	visualPoint = valid.any,
	column = valid.any,
	type = valid.any,
	weight = valid.any,
	data = valid.any,
})

---@return boolean?
---@return string?
function Note:validate()
	return valid.format(validate_note(self))
end

return Note
