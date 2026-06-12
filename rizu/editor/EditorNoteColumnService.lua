local class = require("class")

---@class rizu.editor.EditorNoteColumnService
---@operator call: rizu.editor.EditorNoteColumnService
---@field editorModel rizu.editor.EditorModel
---@field columnOver integer?
local EditorNoteColumnService = class()

function EditorNoteColumnService:new()
end

---@param editorModel rizu.editor.EditorModel
function EditorNoteColumnService:setEditorModel(editorModel)
	self.editorModel = editorModel
end

---@return number
function EditorNoteColumnService:getColumnOver()
	if self.columnOver then
		return self.columnOver
	end
	local editorModel = self.editorModel
	local mx, _my = editorModel.getMousePosition()
	local noteSkin = assert(editorModel:getNoteSkin())
	return noteSkin:getInverseColumnPosition(mx)
end

return EditorNoteColumnService
