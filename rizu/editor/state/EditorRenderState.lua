local class = require("class")

---@class rizu.editor.EditorRenderState
---@operator call: rizu.editor.EditorRenderState
---@field noteSkin table?
local EditorRenderState = class()

---@param noteSkin table?
function EditorRenderState:setNoteSkin(noteSkin)
	self.noteSkin = noteSkin
end

---@return table?
function EditorRenderState:getNoteSkin()
	return self.noteSkin
end

return EditorRenderState
