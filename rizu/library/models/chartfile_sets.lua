local ClientChartfileSet = require("sea.chart.ClientChartfileSet")

local chartfile_sets = {}

chartfile_sets.metatable = ClientChartfileSet

chartfile_sets.types = {
	is_file = "boolean",
}

return chartfile_sets
