local class = require("class")
local VisualEngine = require("rizu.engine.visual.VisualEngine")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local ChartDecoder = require("chart.format.sph.ChartDecoder")
local SphPreview = require("chart.format.sph.SphPreview")
local Sph = require("chart.format.sph.Sph")
local BaseSkinInfo = require("sphere.models.NoteSkinModel.BaseSkinInfo")
local ComputeContext = require("sea.compute.ComputeContext")
local Settings = require("rizu.config.Settings")

---@class rizu.preview.NotesPreviewPlayer
---@operator call: rizu.preview.NotesPreviewPlayer
local NotesPreviewPlayer = class()

---@param settings rizu.config.Config
---@param previewModel rizu.preview.PreviewModel
---@param replayBase sea.ReplayBase
---@param game table
function NotesPreviewPlayer:new(settings, previewModel, replayBase, game)
	self.settings = settings
	self.previewModel = previewModel
	self.replayBase = replayBase
	self.game = game
	self.visual_info = VisualInfo()
	self.visual_engine = VisualEngine(self.visual_info)
	self.skin_info = BaseSkinInfo()
	self.graphicEngine = self

	---@type {[string]: sphere.BaseNoteSkin}
	self.skin_by_mode = {}
end

---@param inputMode string
function NotesPreviewPlayer:getNoteSkin(inputMode)
	local skin_by_mode = self.skin_by_mode
	local noteSkin = skin_by_mode[inputMode]
	if noteSkin then
		return noteSkin
	end
	noteSkin = assert(self.skin_info:loadSkin(inputMode))
	noteSkin:loadData()
	skin_by_mode[inputMode] = noteSkin
	return noteSkin
end

local empty_lines = SphPreview:previewLinesToLines({
	{offset = 0},
	{offset = 1},
})

---@param chartview rizu.library.Chartview
function NotesPreviewPlayer:setChartview(chartview)
	if not self.settings:getBoolean(Settings.keys.select.chart_preview) or not chartview then
		self.chart = nil
		return
	end

	local notes_preview = chartview.notes_preview

	local lines = empty_lines
	if notes_preview and notes_preview ~= "" then
		lines = SphPreview:decodeLines(notes_preview)
	end

	local sph = Sph()
	sph.metadata:set("title", "")
	sph.metadata:set("artist", "")
	sph.metadata:set("input", assert(chartview.chartdiff_inputmode))
	sph.sphLines:decode(lines)

	local decoder = ChartDecoder()

	local ok, chart = pcall(decoder.decodeSph, decoder, sph)
	if not ok then
		self.chart = nil
		return
	end

	local ctx = ComputeContext()
	ctx.chart = chart

	local columns_order = self.replayBase.columns_order
	if columns_order and #columns_order == chart.inputMode:getColumns() then
		ctx:applyColumnOrder(self.replayBase.columns_order)
	end

	local noteSkin = self:getNoteSkin(tostring(chart.inputMode))
	self.playField = noteSkin.playField
	self.noteSkin = noteSkin

	local keys = Settings.keys.gameplay
	local visual_rate = self.settings:getNumber(keys.speed)
	if not self.settings:getBoolean(keys.scale_speed) then
		visual_rate = visual_rate / self.previewModel.rate
	end
	self.visual_info.rate = visual_rate

	self.visual_engine:load(chart, true)

	self.chart = chart
end

function NotesPreviewPlayer:update()
	if not self.chart then
		return
	end

	local keys = Settings.keys.gameplay
	local visual_rate = self.settings:getNumber(keys.speed)
	if not self.settings:getBoolean(keys.scale_speed) then
		visual_rate = visual_rate / self.previewModel.rate
	end
	self.visual_info.rate = visual_rate

	self.visual_info.time = self.previewModel:getTime()
	self.visual_engine:update()
end

---@generic T
---@param f fun(obj: T, note: rizu.VisualNote)
---@param obj T
function NotesPreviewPlayer:iterNotes(f, obj)
	if not self.chart then
		return
	end
	for _, note in ipairs(self.visual_engine.visible_notes) do
		f(obj, note)
	end
end

return NotesPreviewPlayer
