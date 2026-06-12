local class = require("class")

---@class rizu.editor.EditorHistoryContext

---@class rizu.editor.EditorHistoryService
---@operator call: rizu.editor.EditorHistoryService
local EditorHistoryService = class()

---@param context rizu.editor.EditorHistoryContext
function EditorHistoryService:undo(context)
	context:getEditorChanges():undo()
end

---@param context rizu.editor.EditorHistoryContext
function EditorHistoryService:redo(context)
	context:getEditorChanges():redo()
end

return EditorHistoryService
