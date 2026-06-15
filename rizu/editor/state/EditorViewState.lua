local class = require("class")

---@class rizu.editor.EditorViewState
---@operator call: rizu.editor.EditorViewState
---@field overlayState string
---@field dragging boolean?
---@field draggingOwner string?
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
---@param owner string?
function EditorViewState:setDragging(dragging, owner)
	self.dragging = dragging
	self.draggingOwner = dragging and owner or nil
end

---@param owner string?
---@return boolean
function EditorViewState:isDragging(owner)
	if owner then
		return self.dragging == true and self.draggingOwner == owner
	end
	return self.dragging == true
end

return EditorViewState
