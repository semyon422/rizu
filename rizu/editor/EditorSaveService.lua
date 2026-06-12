local class = require("class")

---@class rizu.editor.EditorSaveContext
---@field metadata chart.sph.Metadata
---@field setChartmeta fun(chartmeta: table)
---@field noteChartLoader rizu.editor.NoteChartLoader

---@class rizu.editor.EditorSaveService
---@operator call: rizu.editor.EditorSaveService
local EditorSaveService = class()

---@param context rizu.editor.EditorSaveContext
function EditorSaveService:save(context)
	context.setChartmeta(context.metadata:toChartmeta())
	context.noteChartLoader:save()
end

return EditorSaveService
