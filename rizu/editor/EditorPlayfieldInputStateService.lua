local class = require("class")
local just = require("just")

---@alias rizu.editor.EditorPlayfieldMouseButtonFunc fun(button: integer): boolean

---@class rizu.editor.EditorRhythmInputState
---@field leftPressed boolean
---@field rightPressed boolean
---@field leftReleased boolean

---@class rizu.editor.EditorPlayfieldInputStateServiceDeps
---@field mousePressed rizu.editor.EditorPlayfieldMouseButtonFunc?
---@field mouseReleased rizu.editor.EditorPlayfieldMouseButtonFunc?

---@class rizu.editor.EditorPlayfieldInputStateService
---@operator call: rizu.editor.EditorPlayfieldInputStateService
---@field mousePressed rizu.editor.EditorPlayfieldMouseButtonFunc
---@field mouseReleased rizu.editor.EditorPlayfieldMouseButtonFunc
local EditorPlayfieldInputStateService = class()

---@param deps rizu.editor.EditorPlayfieldInputStateServiceDeps?
function EditorPlayfieldInputStateService:new(deps)
	deps = deps or {}
	self.mousePressed = deps.mousePressed or just.mousepressed
	self.mouseReleased = deps.mouseReleased or just.mousereleased
end

---@return rizu.editor.EditorRhythmInputState
function EditorPlayfieldInputStateService:getState()
	return {
		leftPressed = self.mousePressed(1),
		rightPressed = self.mousePressed(2),
		leftReleased = self.mouseReleased(1),
	}
end

return EditorPlayfieldInputStateService
