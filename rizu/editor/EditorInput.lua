local class = require("class")
local just = require("just")

---@class rizu.editor.EditorInput
---@operator call: rizu.editor.EditorInput
local EditorInput = class()

---@return boolean
function EditorInput:isMultiSelectRequested()
	return love.keyboard.isDown("lctrl")
end

---@return boolean
function EditorInput:isModifierApplyRequested()
	return love.keyboard.isDown("lshift")
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
	just.select(x1, y1, x2, y2)
end

function EditorInput:unselectRegion()
	just.unselect()
end

return EditorInput
