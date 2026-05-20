local class = require("class")
local ChartEncoder = require("chart.format.osu.ChartEncoder")
local ModifierModel = require("sphere.models.ModifierModel")

---@class rizu.library.ChartExporter
---@operator call: rizu.library.ChartExporter
local ChartExporter = class()

---@param library rizu.library.Library
function ChartExporter:new(library)
	self.library = library
end

---@param chartSelector rizu.select.ChartSelector
---@param replayBase sea.ReplayBase
function ChartExporter:exportToOsu(chartSelector, replayBase)
	local chartview = chartSelector.chartview
	if not chartview then
		return
	end

	local encoder = ChartEncoder()

	local chart, chartmeta = chartSelector:loadChartAbsolute()
	ModifierModel:apply(replayBase.modifiers, chart)

	local data = encoder:encode({{
		chart = chart,
		chartmeta = chartmeta,
	}})

	local path = chartview.path
	path = path:find("^.+/.$") and path:match("^(.+)/.$") or path
	local fileName = path:match("^.+/(.-)$"):match("^(.+)%..-$")

	assert(love.filesystem.write(("userdata/export/%s.osu"):format(fileName), data))
end

return ChartExporter
