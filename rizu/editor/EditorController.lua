local class = require("class")
local BmsKeysoundSlicer = require("rizu.editor.exports.BmsKeysoundSlicer")
local BmsTemplateExporter = require("rizu.editor.exports.BmsTemplateExporter")
local UbmscExporter = require("rizu.editor.exports.UbmscExporter")

local dpairs = require("dpairs")
local path_util = require("path_util")
local table_util = require("table_util")
local string_util = require("string_util")
local ChartEncoder = require("chart.format.sph.ChartEncoder")
local ChartDecoder = require("chart.format.sph.ChartDecoder")
local BmsChartDecoder = require("chart.format.bms.ChartDecoder")
local OsuChartEncoder = require("chart.format.osu.ChartEncoder")
local NanoChart = require("chart.transform.NanoChart")
local InputMode = require("chart.core.InputMode")
local zlib = require("zlib")
local SphPreview = require("chart.format.sph.SphPreview")
local ModifierModel = require("sphere.models.ModifierModel")
local Wave = require("audio.Wave")
local base36 = require("chart.format.bms.base36")
local decibel = require("decibel")
local md5 = require("md5")

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
	resource_loader
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
end

function EditorController:load()

	local chartSelector = self.chartSelector
	local editorModel = self.editorModel
	local configModel = self.configModel
	local fileFinder = self.fileFinder

	local chart, chartmeta = chartSelector:loadChart()

	if love.keyboard.isDown("lshift") then
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

	fileFinder:reset()
	self.resource_finder:reset()
	for _, path in ipairs(paths) do
		fileFinder:addPath(path)
		self.resource_finder:addPath(path)
	end

	self.resource_loader:load(chart.resources)

	self.resourceModel:load(chart, function()
		editorModel:loadResources(self.resource_loader.resources)
	end)

	self.windowModel:setVsyncOnSelect(false)
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

	assert(love.filesystem.write(path, data))

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

	assert(love.filesystem.write(path, data))
end

function EditorController:saveToNanoChart()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()

	local nanoChart = NanoChart()

	local abs_notes = {}

	for noteDatas, inputType, inputIndex, layerDataIndex in editorModel.noteChart:getInputIterator() do
		for _, noteData in ipairs(noteDatas) do
			if inputType == "key" and (noteData.noteType == "ShortNote" or noteData.noteType == "LongNoteStart") then
				abs_notes[#abs_notes + 1] = {
					time = noteData.timePoint.absoluteTime,
					type = 1,
					input = 1,
				}
			end
		end
	end

	local emptyHash = string_util.char(0):rep(16)
	local content = nanoChart:encode(emptyHash, editorModel.noteChart.inputMode.key, abs_notes)
	local compressedContent = zlib.compress(content)

	local chartview = chartSelector.chartview

	local path = chartview.real_path

	local f = assert(io.open(path .. ".nanochart_compressed", "w"))
	f:write(compressedContent)
	f:close()
	local f = assert(io.open(path .. ".nanochart", "w"))
	f:write(content)
	f:close()

	local exp = NoteChartExporter()
	exp.noteChart = editorModel.noteChart
	local sph_chart = exp:export()

	local content = SphPreview:encodeLines(exp.sph.sphLines:encode())
	local compressedContent = zlib.compress(content)

	local content1 = SphPreview:encodeLines(exp.sph.sphLines:encode(), 1)
	local compressedContent1 = zlib.compress(content1)

	local f = assert(io.open(path .. ".preview0_compressed", "w"))
	f:write(compressedContent)
	f:close()
	local f = assert(io.open(path .. ".preview0", "w"))
	f:write(content)
	f:close()
	local f = assert(io.open(path .. ".preview1_compressed", "w"))
	f:write(compressedContent1)
	f:close()
	local f = assert(io.open(path .. ".preview1", "w"))
	f:write(content1)
	f:close()
	-- local f = assert(io.open(path .. ".preview_lines", "w"))
	-- f:write(require("inspect")(lines))
	-- f:close()
end

---@param event table
function EditorController:receive(event)
	self.editorModel:receive(event)
	if event.name == "filedropped" then
		self:filedropped(event[1])
	end
end

local exts = {
	mp3 = true,
	ogg = true,
}

---@param file love.File
function EditorController:filedropped(file)
	local path = file:getFilename():gsub("\\", "/")

	local _name, ext = path:match("^(.+)%.(.-)$")
	if not exts[ext] then
		return
	end

	local audioName = _name:match("^.+/(.-)$")
	local chartSetPath = "userdata/charts/editor/" .. os.time() .. " " .. audioName

	love.filesystem.write(chartSetPath .. "/" .. audioName .. "." .. ext, file:read())
end

return EditorController
