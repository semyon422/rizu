local class = require("class")

local IidxResourcePaths = require("rizu.library.iidx.ResourcePaths")
local ModifierModel = require("sphere.models.ModifierModel")
local Settings = require("rizu.config.Settings")

---@class rizu.editor.EditorLoadControllerServiceDeps
---@field modifierModel sphere.ModifierModel?

---@class rizu.editor.EditorLoadControllerContext
---@field chartSelector rizu.select.ChartSelector
---@field editorModel rizu.editor.EditorModel
---@field noteSkinModel sphere.NoteSkinModel
---@field settings rizu.config.Config
---@field windowModel rizu.WindowModel
---@field fileFinder sphere.FileFinder
---@field previewModel rizu.preview.PreviewModel
---@field replayBase sea.ReplayBase
---@field resource_finder rizu.ResourceFinder
---@field resource_loader rizu.ResourceLoader
---@field fs fs.IFilesystem
---@field isModifierApplyRequested fun(): boolean

---@class rizu.editor.EditorLoadControllerService
---@operator call: rizu.editor.EditorLoadControllerService
---@field modifierModel sphere.ModifierModel
local EditorLoadControllerService = class()

---@param deps rizu.editor.EditorLoadControllerServiceDeps?
function EditorLoadControllerService:new(deps)
	deps = deps or {}
	self.modifierModel = deps.modifierModel or ModifierModel
end

---@param context rizu.editor.EditorLoadControllerContext
function EditorLoadControllerService:load(context)
	local chartSelector = context.chartSelector
	local editorModel = context.editorModel

	local chart, chartmeta = chartSelector:loadChart()

	if context.isModifierApplyRequested() then
		self.modifierModel:apply(context.replayBase.modifiers, chart)
	end

	local chartview = chartSelector.chartview

	local noteSkin = context.noteSkinModel:loadNoteSkin(tostring(chart.inputMode))
	noteSkin:loadData()
	noteSkin.editor = true

	editorModel:setNoteSkin(noteSkin)
	editorModel.chart = chart
	editorModel.chartmeta = chartmeta
	editorModel:load()

	context.previewModel:stop()

	local paths = self:getResourcePaths(context.settings, chartview, noteSkin, context.fs)
	self:loadResourcePaths(context.fileFinder, context.resource_finder, paths)

	context.resource_loader:load(chart.resources)
	editorModel:loadResources(context.resource_loader.resources)

	context.windowModel:setVsyncOnSelect(false)
end

---@param settings rizu.config.Config
---@param chartview table
---@param noteSkin table
---@param fs fs.IFilesystem?
---@return string[]
function EditorLoadControllerService:getResourcePaths(settings, chartview, noteSkin, fs)
	local paths = {}
	if settings:getBoolean(Settings.keys.gameplay.skin_resources_top_priority) then
		table.insert(paths, noteSkin.directoryPath)
		table.insert(paths, chartview.location_dir)
	else
		table.insert(paths, chartview.location_dir)
		table.insert(paths, noteSkin.directoryPath)
	end
	local movie_path = IidxResourcePaths.getMoviePath(chartview, fs)
	if movie_path then
		table.insert(paths, movie_path)
	end
	table.insert(paths, "userdata/hitsounds")
	table.insert(paths, "userdata/hitsounds/midi")
	return paths
end

---@param fileFinder sphere.FileFinder
---@param resourceFinder rizu.ResourceFinder
---@param paths string[]
function EditorLoadControllerService:loadResourcePaths(fileFinder, resourceFinder, paths)
	fileFinder:reset()
	resourceFinder:reset()
	for _, path in ipairs(paths) do
		fileFinder:addPath(path)
		resourceFinder:addPath(path)
	end
end

return EditorLoadControllerService
