local class = require("class")

---@class rizu.editor.EditorViewState
---@operator call: rizu.editor.EditorViewState
---@field overlayState string
---@field dragging boolean?
local EditorViewState = class()

function EditorViewState:new()
	self.overlayState = "info"
end

---@param state string
function EditorViewState:setOverlayState(state)
	self.overlayState = state
end

---@return string
function EditorViewState:getOverlayState()
	return self.overlayState
end

---@param dragging boolean
function EditorViewState:setDragging(dragging)
	self.dragging = dragging
end

---@return boolean
function EditorViewState:isDragging()
	return self.dragging == true
end

return EditorViewState
