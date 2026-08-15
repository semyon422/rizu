local class = require("class")
local EditorDropImport = require("rizu.editor.controller.EditorDropImport")
local EditorExportService = require("rizu.editor.controller.EditorExportService")
local EditorLoadControllerService = require("rizu.editor.controller.EditorLoadControllerService")
local LoveFilesystem = require("fs.LoveFilesystem")

---@class rizu.editor.EditorControllerDeps
---@field chartSelector rizu.select.ChartSelector
---@field editorModel rizu.editor.EditorModel
---@field noteSkinModel sphere.NoteSkinModel
---@field settings rizu.config.Config
---@field windowModel rizu.WindowModel
---@field library rizu.library
---@field fileFinder sphere.FileFinder
---@field previewModel rizu.preview.PreviewModel
---@field replayBase sea.ReplayBase
---@field resource_finder rizu.ResourceFinder
---@field resource_loader rizu.ResourceLoader
---@field fs fs.IFilesystem?
---@field isModifierApplyRequested (fun(): boolean)?
---@field dropImport rizu.editor.EditorDropImport?
---@field exportService rizu.editor.EditorExportService?
---@field loadControllerService rizu.editor.EditorLoadControllerService?
---@field modifierModel sphere.ModifierModel?
---@field bmsKeysoundSlicer rizu.editor.exports.BmsKeysoundSlicer?
---@field bmsTemplateExporter rizu.editor.exports.BmsTemplateExporter?
---@field ubmscExporter rizu.editor.exports.UbmscExporter?
---@field sphChartSaver rizu.editor.exports.SphChartSaver?
---@field osuChartExporter rizu.editor.exports.OsuChartExporter?
---@field nanoChartExporter rizu.editor.exports.NanoChartExporter?

---@class rizu.editor.EditorController
---@operator call: rizu.editor.EditorController
local EditorController = class()

---@param deps rizu.editor.EditorControllerDeps
function EditorController:new(deps)
	self.chartSelector = deps.chartSelector
	self.editorModel = deps.editorModel
	self.noteSkinModel = deps.noteSkinModel
	self.settings = assert(deps.settings, "settings are required")
	self.windowModel = deps.windowModel
	self.library = deps.library
	self.fileFinder = deps.fileFinder
	self.previewModel = deps.previewModel
	self.replayBase = deps.replayBase
	self.resource_finder = deps.resource_finder
	self.resource_loader = deps.resource_loader
	self.fs = deps.fs or LoveFilesystem()
	self.isModifierApplyRequested = deps.isModifierApplyRequested or function()
		return false
	end
	self.dropImport = deps.dropImport or EditorDropImport(self.fs)
	self.loadControllerService = deps.loadControllerService or EditorLoadControllerService({
		modifierModel = deps.modifierModel,
	})
	self.exportService = deps.exportService or EditorExportService(self.fs, {
		bmsKeysoundSlicer = deps.bmsKeysoundSlicer,
		bmsTemplateExporter = deps.bmsTemplateExporter,
		ubmscExporter = deps.ubmscExporter,
		sphChartSaver = deps.sphChartSaver,
		osuChartExporter = deps.osuChartExporter,
		nanoChartExporter = deps.nanoChartExporter,
	})
end

function EditorController:load()
	self.loadControllerService:load(self:createLoadControllerContext())
end

---@return rizu.editor.EditorLoadControllerContext
function EditorController:createLoadControllerContext()
	return {
		chartSelector = self.chartSelector,
		editorModel = self.editorModel,
		noteSkinModel = self.noteSkinModel,
		settings = self.settings,
		windowModel = self.windowModel,
		fileFinder = self.fileFinder,
		previewModel = self.previewModel,
		replayBase = self.replayBase,
		resource_finder = self.resource_finder,
		resource_loader = self.resource_loader,
		isModifierApplyRequested = self.isModifierApplyRequested,
	}
end

function EditorController:unload()
	self.editorModel:unload()

	self.windowModel:setVsyncOnSelect(true)
end

function EditorController:sliceKeysounds()
	self.exportService:sliceKeysounds(self.chartSelector, self.editorModel)
end

function EditorController:exportUBmsC()
	self.exportService:exportUBmsC(self.chartSelector, self.editorModel)
end

function EditorController:exportBmsTemplate(columns_out)
	self.exportService:exportBmsTemplate(self.chartSelector, self.editorModel, columns_out)
end

function EditorController:save()
	self.exportService:save(self.chartSelector.chartview, self.editorModel, self.library)
end

function EditorController:saveToOsu()
	self.exportService:saveToOsu(self.chartSelector.chartview, self.editorModel)
end

function EditorController:saveToNanoChart()
	self.exportService:saveToNanoChart(self.chartSelector.chartview, self.editorModel)
end

---@param event table
function EditorController:receive(event)
	self.editorModel:receive(event)
	if event.name == "filedropped" then
		self:filedropped(event[1])
	end
end

---@param file love.File
function EditorController:filedropped(file)
	self.dropImport:import(file)
end

return EditorController
