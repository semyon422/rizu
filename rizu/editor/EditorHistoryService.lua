local class = require("class")

---@class rizu.editor.EditorHistoryContext
---@field editorChanges rizu.editor.EditorChanges

---@class rizu.editor.EditorHistoryService
---@operator call: rizu.editor.EditorHistoryService
local EditorHistoryService = class()

---@param context rizu.editor.EditorHistoryContext
function EditorHistoryService:undo(context)
	context.editorChanges:undo()
end

---@param context rizu.editor.EditorHistoryContext
function EditorHistoryService:redo(context)
	context.editorChanges:redo()
end

return EditorHistoryService
