local table_util = require("table_util")
local valid = require("valid")
local chart_types = require("sea.chart.types")
local ChartplayBase = require("sea.chart.ChartplayBase")
local TimingValues = require("sea.chart.TimingValues")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

---@class sea.ReplayBase: sea.ChartplayBase
---@operator call: sea.ReplayBase
---@field timing_values sea.TimingValues for backward compatibility
local ReplayBase = ChartplayBase + {}

function ReplayBase:new()
	ChartplayBase.new(self)
	self.timing_values = assert(TimingValuesFactory:get(self.timings))
end

ReplayBase.struct = {
	timing_values = chart_types.timing_values,
}
table_util.copy(ChartplayBase.struct, ReplayBase.struct)

assert(#table_util.keys(ReplayBase.struct) == 13)

local validate_replay_base = valid.struct(ReplayBase.struct)

---@return true?
---@return string|valid.Errors?
function ReplayBase:validate()
	return validate_replay_base(self)
end

---@param base sea.ReplayBase
function ReplayBase:importReplayBase(base)
	for k in pairs(ReplayBase.struct) do
		self[k] = base[k] ---@diagnostic disable-line
	end
	if self.timing_values then
		setmetatable(self.timing_values, TimingValues)
	end
end

---@param base sea.ReplayBase
function ReplayBase:exportReplayBase(base)
	for k in pairs(ReplayBase.struct) do
		base[k] = self[k] ---@diagnostic disable-line
	end
end

return ReplayBase
