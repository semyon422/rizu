local class = require("class")
local Converter = require("chart.chartedit.Converter")

---@class rizu.editor.NoteChartLoaderContext
---@field getChart fun(): chart.Chart
---@field getLayer fun(): chartedit.Layer
---@field getNotes fun(): chartedit.Notes

---@class rizu.editor.NoteChartLoader
---@operator call: rizu.editor.NoteChartLoader
---@field context rizu.editor.NoteChartLoaderContext
local NoteChartLoader = class()

---@param context rizu.editor.NoteChartLoaderContext
function NoteChartLoader:setContext(context)
	self.context = context
end

---@return chartedit.Layer
---@return chartedit.Notes
function NoteChartLoader:load()
	local chart = self.context.getChart()
	chart.layers.main:toInterval()
	local layers, notes = Converter:load(chart)
	return layers.main, notes
end

function NoteChartLoader:save()
	local chart = Converter:save({main = self.context.getLayer()}, self.context.getNotes())
	local targetChart = self.context.getChart()
	targetChart.layers.main = chart.layers.main
	targetChart.notes = chart.notes
end

return NoteChartLoader
