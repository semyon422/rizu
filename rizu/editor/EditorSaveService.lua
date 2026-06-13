local class = require("class")

---@class rizu.editor.EditorSaveContext
---@field setChartmeta fun(self: rizu.editor.EditorSaveContext, chartmeta: table)
---@field getMetadata fun(self: rizu.editor.EditorSaveContext): chart.sph.Metadata
---@field getNoteChartLoader fun(self: rizu.editor.EditorSaveContext): rizu.editor.NoteChartLoader

---@class rizu.editor.EditorSaveService
---@operator call: rizu.editor.EditorSaveService
local EditorSaveService = class()

---@param context rizu.editor.EditorSaveContext
function EditorSaveService:save(context)
	context:setChartmeta(context:getMetadata():toChartmeta())
	context:getNoteChartLoader():save()
end

return EditorSaveService
