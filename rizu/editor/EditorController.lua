local class = require("class")
local BmsKeysoundSlicer = require("rizu.editor.exports.BmsKeysoundSlicer")
local BmsTemplateExporter = require("rizu.editor.exports.BmsTemplateExporter")
local EditorDropImport = require("rizu.editor.EditorDropImport")
local NanoChartExporter = require("rizu.editor.exports.NanoChartExporter")
local OsuChartExporter = require("rizu.editor.exports.OsuChartExporter")
local SphChartSaver = require("rizu.editor.exports.SphChartSaver")
local UbmscExporter = require("rizu.editor.exports.UbmscExporter")
local LoveFilesystem = require("fs.LoveFilesystem")

local ModifierModel = require("sphere.models.ModifierModel")

---@class rizu.editor.EditorControllerDeps
---@field chartSelector rizu.select.ChartSelector
---@field editorModel rizu.editor.EditorModel
---@field noteSkinModel sphere.NoteSkinModel
---@field configModel sphere.ConfigModel
---@field resourceModel sphere.ResourceModel
---@field windowModel sphere.WindowModel
---@field library rizu.library
---@field fileFinder sphere.FileFinder
---@field previewModel rizu.preview.PreviewModel
---@field replayBase sea.ReplayBase
---@field resource_finder rizu.ResourceFinder
---@field resource_loader rizu.ResourceLoader
---@field fs fs.IFilesystem?
---@field isModifierApplyRequested (fun(): boolean)?
---@field dropImport rizu.editor.EditorDropImport?
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
	self.configModel = deps.configModel
	self.resourceModel = deps.resourceModel
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
	self.sphChartSaver = deps.sphChartSaver or SphChartSaver(self.fs)
	self.osuChartExporter = deps.osuChartExporter or OsuChartExporter(self.fs)
	self.nanoChartExporter = deps.nanoChartExporter or NanoChartExporter(self.fs)
end

function EditorController:load()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	local chart, chartmeta = chartSelector:loadChart()

	if self.isModifierApplyRequested() then
		ModifierModel:apply(self.replayBase.modifiers, chart)
	end

	local chartview = chartSelector.chartview

	local noteSkin = self.noteSkinModel:loadNoteSkin(tostring(chart.inputMode))
	noteSkin:loadData()
	noteSkin.editor = true

	editorModel:setNoteSkin(noteSkin)
	editorModel.chart = chart
	editorModel.chartmeta = chartmeta
	editorModel:load()

	self.previewModel:stop()

	local paths = self:getResourcePaths(chartview, noteSkin)
	self:loadResourcePaths(paths)

	self.resource_loader:load(chart.resources)

	self.resourceModel:load(chart, function()
		editorModel:loadResources(self.resource_loader.resources)
	end)

	self.windowModel:setVsyncOnSelect(false)
end

---@param chartview table
---@param noteSkin table
---@return string[]
function EditorController:getResourcePaths(chartview, noteSkin)
	local configModel = self.configModel
	local paths = {}
	if configModel.configs.settings.gameplay.skin_resources_top_priority then
		table.insert(paths, noteSkin.directoryPath)
		table.insert(paths, chartview.location_dir)
	else
		table.insert(paths, chartview.location_dir)
		table.insert(paths, noteSkin.directoryPath)
	end
	table.insert(paths, "userdata/hitsounds")
	table.insert(paths, "userdata/hitsounds/midi")
	return paths
end

---@param paths string[]
function EditorController:loadResourcePaths(paths)
	local fileFinder = self.fileFinder
	fileFinder:reset()
	self.resource_finder:reset()
	for _, path in ipairs(paths) do
		fileFinder:addPath(path)
		self.resource_finder:addPath(path)
	end
end

function EditorController:unload()
	self.editorModel:unload()

	self.windowModel:setVsyncOnSelect(true)
end

function EditorController:sliceKeysounds()
	BmsKeysoundSlicer():slice(self.chartSelector, self.editorModel)
end

function EditorController:exportUBmsC()
	UbmscExporter():export(self.chartSelector, self.editorModel)
end

function EditorController:exportBmsTemplate(columns_out)
	BmsTemplateExporter():export(self.chartSelector, self.editorModel, columns_out)
end

function EditorController:save()
	self.sphChartSaver:save(self.chartSelector.chartview, self.editorModel, self.library)
end

function EditorController:saveToOsu()
	self.osuChartExporter:export(self.chartSelector.chartview, self.editorModel)
end

function EditorController:saveToNanoChart()
	self.nanoChartExporter:export(self.chartSelector.chartview, self.editorModel)
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
