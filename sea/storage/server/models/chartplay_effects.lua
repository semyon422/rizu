local ChartplayEffect = require("sea.compute.ChartplayEffect")
local ChartplayEffectType = require("sea.compute.ChartplayEffectType")
local ComputeJobState = require("sea.compute.ComputeJobState")

---@type rdb.ModelOptions
local chartplay_effects = {}

chartplay_effects.metatable = ChartplayEffect
chartplay_effects.types = {
	effect = ChartplayEffectType,
	state = ComputeJobState,
}

return chartplay_effects
