local Pattern = require("chart.scoring.Pattern")
local Skillset = require("chart.scoring.Skillset")

local chart_patterns = {}

chart_patterns.table_name = "chart_patterns"

chart_patterns.types = {
	skillset = Skillset,
	pattern_1 = Pattern,
	pattern_2 = Pattern,
}

chart_patterns.relations = {}

return chart_patterns
