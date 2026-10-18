local Chartfile = require("sea.chart.Chartfile")
local ComputeState = require("sea.compute.ComputeState")

---@type rdb.ModelOptions
local chartfiles = {}

chartfiles.metatable = Chartfile

chartfiles.types = {
	compute_state = ComputeState,
}

return chartfiles
