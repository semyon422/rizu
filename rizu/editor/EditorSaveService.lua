local class = require("class")

---@class rizu.editor.EditorSaveContext

---@class rizu.editor.EditorSaveService
---@operator call: rizu.editor.EditorSaveService
local EditorSaveService = class()

---@param context rizu.editor.EditorSaveContext
function EditorSaveService:save(context)
	context:setChartmeta(context:getMetadata():toChartmeta())
	context:getNoteChartLoader():save()
end

return EditorSaveService
