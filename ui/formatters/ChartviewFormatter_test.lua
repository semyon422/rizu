local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")

local test = {}

---@param t testing.T
function test.formats_chart_mode(t)
	local formatter = ChartviewFormatter({chartdiff_inputmode = "7key1scratch"}, {})
	t:eq(formatter:getMode(), "7K1S")

	formatter:setChartview({mode = "taiko"})
	t:eq(formatter:getMode(), "TAIKO")

	formatter:setChartview()
	t:eq(formatter:getMode(), "NO CHART")
end

return test
