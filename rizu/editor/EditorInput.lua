local class = require("class")

---@class rizu.editor.EditorInput
---@operator call: rizu.editor.EditorInput
local EditorInput = class()

---@param left string
---@param right string
---@return boolean
local function isModifierDown(left, right)
	return love.keyboard.isDown(left) or love.keyboard.isDown(right)
end

---@return boolean
function EditorInput:isMultiSelectRequested()
	return isModifierDown("lctrl", "rctrl")
end

---@return boolean
function EditorInput:isEditorCommandRequested()
	return isModifierDown("lctrl", "rctrl")
end

---@return boolean
function EditorInput:isModifierApplyRequested()
	return isModifierDown("lshift", "rshift")
end

---@return boolean
function EditorInput:isFineScrollRequested()
	return isModifierDown("lalt", "ralt")
end

---@return boolean
function EditorInput:isSnapChangeRequested()
	return isModifierDown("lshift", "rshift")
end

---@return boolean
function EditorInput:isSpeedChangeRequested()
	return isModifierDown("lctrl", "rctrl")
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
