local class = require("class")

---@class rizu.editor.EditorInput
---@operator call: rizu.editor.EditorInput
local EditorInput = class()

---@return boolean
function EditorInput:isMultiSelectRequested()
	return love.keyboard.isDown("lctrl")
end

---@return boolean
function EditorInput:isEditorCommandRequested()
	return love.keyboard.isDown("lctrl")
end

---@return boolean
function EditorInput:isModifierApplyRequested()
	return love.keyboard.isDown("lshift")
end

---@return boolean
function EditorInput:isFineScrollRequested()
	return love.keyboard.isDown("lalt")
end

---@return boolean
function EditorInput:isSnapChangeRequested()
	return love.keyboard.isDown("lshift")
end

---@return boolean
function EditorInput:isSpeedChangeRequested()
	return love.keyboard.isDown("lctrl")
end

---@return number
---@return number
function EditorInput:getMousePosition()
	return love.graphics.inverseTransformPoint(love.mouse.getPosition())
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function EditorInput:selectRegion(x1, y1, x2, y2)
end

function EditorInput:unselectRegion()
end

return EditorInput
