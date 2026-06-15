local class = require("class")
local Point = require("chart.chartedit.Point")

---@class rizu.editor.EditorCursorState
---@operator call: rizu.editor.EditorCursorState
---@field point chartedit.Point
local EditorCursorState = class()

function EditorCursorState:new()
	self.point = Point()
end

---@return chartedit.Point
function EditorCursorState:getPoint()
	return self.point
end

---@return number
function EditorCursorState:getTime()
	return rawget(self.point, "absoluteTime")
end

---@param point chartedit.Point
function EditorCursorState:setPoint(point)
	if point.clone then
		point:clone(self.point)
		return
	end

	for key, value in pairs(point) do
		self.point[key] = value
	end
end

---@param point chartedit.Point
function EditorCursorState:reset(point)
	self:setPoint(point)
end

return EditorCursorState
