local Enum = require("rdb.Enum")

---@enum (key) sea.ChartplayEffectType
local ChartplayEffectType = {
	external_ranked = 0,
	leaderboards = 1,
	activity = 2,
	user_aggregates = 3,
	dan = 4,
	notification = 5,
}

return Enum(ChartplayEffectType)
