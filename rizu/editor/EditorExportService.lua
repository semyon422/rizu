local class = require("class")
local BmsKeysoundSlicer = require("rizu.editor.exports.BmsKeysoundSlicer")
local BmsTemplateExporter = require("rizu.editor.exports.BmsTemplateExporter")
local NanoChartExporter = require("rizu.editor.exports.NanoChartExporter")
local OsuChartExporter = require("rizu.editor.exports.OsuChartExporter")
local SphChartSaver = require("rizu.editor.exports.SphChartSaver")
local UbmscExporter = require("rizu.editor.exports.UbmscExporter")

---@class rizu.editor.EditorExportServiceDeps
---@field bmsKeysoundSlicer rizu.editor.exports.BmsKeysoundSlicer?
---@field bmsTemplateExporter rizu.editor.exports.BmsTemplateExporter?
---@field ubmscExporter rizu.editor.exports.UbmscExporter?
---@field sphChartSaver rizu.editor.exports.SphChartSaver?
---@field osuChartExporter rizu.editor.exports.OsuChartExporter?
---@field nanoChartExporter rizu.editor.exports.NanoChartExporter?

---@class rizu.editor.EditorExportService
---@operator call: rizu.editor.EditorExportService
---@field bmsKeysoundSlicer rizu.editor.exports.BmsKeysoundSlicer
---@field bmsTemplateExporter rizu.editor.exports.BmsTemplateExporter
---@field ubmscExporter rizu.editor.exports.UbmscExporter
---@field sphChartSaver rizu.editor.exports.SphChartSaver
---@field osuChartExporter rizu.editor.exports.OsuChartExporter
---@field nanoChartExporter rizu.editor.exports.NanoChartExporter
local EditorExportService = class()

---@param fs fs.IFilesystem
---@param deps rizu.editor.EditorExportServiceDeps?
function EditorExportService:new(fs, deps)
	deps = deps or {}
	self.bmsKeysoundSlicer = deps.bmsKeysoundSlicer or BmsKeysoundSlicer()
	self.bmsTemplateExporter = deps.bmsTemplateExporter or BmsTemplateExporter()
	self.ubmscExporter = deps.ubmscExporter or UbmscExporter()
	self.sphChartSaver = deps.sphChartSaver or SphChartSaver(fs)
	self.osuChartExporter = deps.osuChartExporter or OsuChartExporter(fs)
	self.nanoChartExporter = deps.nanoChartExporter or NanoChartExporter(fs)
end

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
function EditorExportService:sliceKeysounds(chartSelector, editorModel)
	self.bmsKeysoundSlicer:slice(chartSelector, editorModel)
end

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
function EditorExportService:exportUBmsC(chartSelector, editorModel)
	self.ubmscExporter:export(chartSelector, editorModel)
end

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
---@param columns_out string[]?
function EditorExportService:exportBmsTemplate(chartSelector, editorModel, columns_out)
	self.bmsTemplateExporter:export(chartSelector, editorModel, columns_out)
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
---@param library rizu.library
function EditorExportService:save(chartview, editorModel, library)
	self.sphChartSaver:save(chartview, editorModel, library)
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
function EditorExportService:saveToOsu(chartview, editorModel)
	self.osuChartExporter:export(chartview, editorModel)
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
function EditorExportService:saveToNanoChart(chartview, editorModel)
	self.nanoChartExporter:export(chartview, editorModel)
end

return EditorExportService
