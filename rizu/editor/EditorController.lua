local class = require("class")
local BmsKeysoundSlicer = require("rizu.editor.exports.BmsKeysoundSlicer")
local BmsTemplateExporter = require("rizu.editor.exports.BmsTemplateExporter")
local EditorDropImport = require("rizu.editor.EditorDropImport")
local NanoChartExporter = require("rizu.editor.exports.NanoChartExporter")
local UbmscExporter = require("rizu.editor.exports.UbmscExporter")
local LoveFilesystem = require("fs.LoveFilesystem")

local ChartEncoder = require("chart.format.sph.ChartEncoder")
local OsuChartEncoder = require("chart.format.osu.ChartEncoder")
local ModifierModel = require("sphere.models.ModifierModel")

---@class rizu.editor.EditorController
---@operator call: rizu.editor.EditorController
local EditorController = class()

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
---@param noteSkinModel sphere.NoteSkinModel
---@param configModel sphere.ConfigModel
---@param resourceModel sphere.ResourceModel
---@param windowModel sphere.WindowModel
---@param library rizu.library
---@param fileFinder sphere.FileFinder
---@param previewModel rizu.preview.PreviewModel
---@param replayBase sea.ReplayBase
---@param resource_finder rizu.ResourceFinder
---@param resource_loader rizu.ResourceLoader
---@param fs fs.IFilesystem?
---@param isModifierApplyRequested (fun(): boolean)?
---@param dropImport rizu.editor.EditorDropImport?
---@param nanoChartExporter rizu.editor.exports.NanoChartExporter?
function EditorController:new(
	chartSelector,
	editorModel,
	noteSkinModel,
	configModel,
	resourceModel,
	windowModel,
	library,
	fileFinder,
	previewModel,
	replayBase,
	resource_finder,
	resource_loader,
	fs,
	isModifierApplyRequested,
	dropImport,
	nanoChartExporter
)
	self.chartSelector = chartSelector
	self.editorModel = editorModel
	self.noteSkinModel = noteSkinModel
	self.configModel = configModel
	self.resourceModel = resourceModel
	self.windowModel = windowModel
	self.library = library
	self.fileFinder = fileFinder
	self.previewModel = previewModel
	self.replayBase = replayBase
	self.resource_finder = resource_finder
	self.resource_loader = resource_loader
	self.fs = fs or LoveFilesystem()
	self.isModifierApplyRequested = isModifierApplyRequested or function()
		return false
	end
	self.dropImport = dropImport or EditorDropImport(self.fs)
	self.nanoChartExporter = nanoChartExporter or NanoChartExporter(self.fs)
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

	editorModel.session.noteSkin = noteSkin
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
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()
	self.editorModel:genGraphs()

	local encoder = ChartEncoder()
	local data = encoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})

	local chartview = chartSelector.chartview
	local path = chartview.location_path:gsub(".sph$", "") .. ".sph"

	assert(self.fs:write(path, data))

	self.library:computeLocation(chartview.dir, chartview.location_id)
end

function EditorController:saveToOsu()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()

	local encoder = OsuChartEncoder()
	local data = encoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})

	local chartview = chartSelector.chartview
	local path = chartview.location_path:gsub(".osu$", ""):gsub(".sph$", "") .. ".sph.osu"

	assert(self.fs:write(path, data))
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
