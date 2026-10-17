local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local ModeNotes = require("chart.model.ModeNotes")

local TestChart = {}

---@param data table
---@param mode sea.Gamemode
---@return chart.Chart
function TestChart.create(data, mode)
	local builder = ChartBuilder()
	ModeNotes.write(builder.chart, builder:createAbsoluteLayer(), builder:getVisual("main"), mode, data)
	builder.chart:compute()
	return builder.chart
end

return TestChart
