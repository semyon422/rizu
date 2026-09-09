local class = require("class")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local Settings = require("rizu.config.Settings")

---@class rizu.preview.NotesPreviewPlayer
---@operator call: rizu.preview.NotesPreviewPlayer
---@field notes rizu.preview.NotesPreview?
---@field column_map integer[]
local NotesPreviewPlayer = class()

---@param settings rizu.config.Config
---@param previewModel rizu.preview.PreviewModel
---@param replayBase sea.ReplayBase
function NotesPreviewPlayer:new(settings, previewModel, replayBase)
	self.settings = settings
	self.previewModel = previewModel
	self.replayBase = replayBase
	self.column_map = {}
	self.time = 0
	self.rate = 1
end

---@param chartview rizu.library.Chartview?
---@return boolean? valid
function NotesPreviewPlayer:setChartview(chartview)
	self.notes = nil
	if not self.settings:getBoolean(Settings.keys.select.chart_preview) or not chartview then
		return
	end
	local columns = InputMode(assert(chartview.chartdiff_inputmode)):getColumns()
	local ok, notes = pcall(NotesPreview, chartview.notes_preview or "", columns)
	if not ok then
		return false
	end
	self.notes = notes
	local order = self.replayBase.columns_order
	local map = {}
	for i = 1, columns do
		map[order and #order == columns and order[i] or i] = i
	end
	self.column_map = map
end

function NotesPreviewPlayer:update()
	local keys = Settings.keys.gameplay
	self.rate = self.settings:getNumber(keys.speed)
	if not self.settings:getBoolean(keys.scale_speed) then
		self.rate = self.rate / self.previewModel.rate
	end
	self.time = self.previewModel:getTime()
end

return NotesPreviewPlayer
