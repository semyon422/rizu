local class = require("class")

---@class rizu.editor.EditorNoteColumnServiceContext
---@field getMousePosition fun(): number, number
---@field getNoteSkin fun(): table?

---@class rizu.editor.EditorNoteColumnService
---@operator call: rizu.editor.EditorNoteColumnService
---@field context rizu.editor.EditorNoteColumnServiceContext
---@field columnOver integer?
local EditorNoteColumnService = class()

function EditorNoteColumnService:new()
end

---@param context rizu.editor.EditorNoteColumnServiceContext
function EditorNoteColumnService:setContext(context)
	self.context = context
end

---@param column integer?
function EditorNoteColumnService:setColumnOver(column)
	self.columnOver = column
end

---@return number
function EditorNoteColumnService:getColumnOver()
	if self.columnOver then
		return self.columnOver
	end
	local mx, _my = self.context:getMousePosition()
	local noteSkin = assert(self.context:getNoteSkin())
	return noteSkin:getInverseColumnPosition(mx)
end

return EditorNoteColumnService
