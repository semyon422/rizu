local class = require("class")

---@class sphere.GraphicalNote
---@operator call: sphere.GraphicalNote
---@field currentVisualPoint chart.IVisualPoint
---@field visual chart.Visual
---@field graphicEngine sphere.GraphicEngine
---@field column chart.Column
local GraphicalNote = class()

---@param noteType string?
---@param note chart.LinkedNote
function GraphicalNote:new(noteType, note)
	self.noteType = noteType
	self.startNote = note and note.startNote
	self.endNote = note and note.endNote
end

function GraphicalNote:update() end

---@return string
function GraphicalNote:getLogicalState()
	local logicalNote = self.graphicEngine:getLogicalNote(self.startNote)
	return logicalNote and logicalNote.state or "clear"
end

---@return number?
function GraphicalNote:getPressedTime()
	local logicalNote = self.graphicEngine:getLogicalNote(self.startNote)
	return logicalNote and logicalNote.pressedTime
end

---@param visualPoint chart.IVisualPoint
---@return number
function GraphicalNote:getVisualTime(visualPoint)
	if self.graphicEngine.constant then
		return visualPoint.point.absoluteTime
	end
	return visualPoint:getVisualTime(self.currentVisualPoint)
end

---@param time number
---@return number
function GraphicalNote:where(time)
	local rate = self.graphicEngine:getVisualTimeRate()
	time = time * rate / math.abs(rate)
	local range = self.graphicEngine.range
	if -time > range[2] then
		return 1
	elseif -time < range[1] then
		return -1
	else
		return 0
	end
end

---@return number
function GraphicalNote:whereWillDraw()
	return 0
end

---@return boolean
function GraphicalNote:willDraw()
	return self:whereWillDraw() == 0
end

---@return boolean
function GraphicalNote:willDrawBeforeStart()
	return self:whereWillDraw() == -1
end

---@return boolean
function GraphicalNote:willDrawAfterEnd()
	return self:whereWillDraw() == 1
end

return GraphicalNote
