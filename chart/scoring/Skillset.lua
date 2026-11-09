local Enum = require("rdb.Enum")

-- Stored in chart_patterns.skillset, so never renumber one.
---@enum (key) chart.scoring.Skillset
local Skillset = {
	speed = 0,
	stamina = 1,
	jacks = 2,
	technical = 3,
}

return Enum(Skillset)
