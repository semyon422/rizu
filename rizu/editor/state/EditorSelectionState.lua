local class = require("class")

---@class rizu.editor.EditorSelectionState
---@operator call: rizu.editor.EditorSelectionState
---@field rect number[]?
---@field startTime number?
local EditorSelectionState = class()

---@param x number
---@param y number
---@param startTime number
function EditorSelectionState:start(x, y, startTime)
	self.rect = {x, y, x, y}
	self.startTime = startTime
end

function EditorSelectionState:finish()
	self.rect = nil
	self.startTime = nil
end

---@return number[]?
function EditorSelectionState:getRect()
	return self.rect
end

---@return number?
function EditorSelectionState:getStartTime()
	return self.startTime
end

---@return boolean
function EditorSelectionState:isActive()
	return self.rect ~= nil
end

---@param x number
---@param y number
---@param rectY number
---@return number[]?
function EditorSelectionState:update(x, y, rectY)
	local rect = self.rect
	if not rect then
		return
	end
	rect[2] = rectY
	rect[3] = x
	rect[4] = y
	return rect
end

return EditorSelectionState
