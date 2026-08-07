local valid = require("valid")
local types = require("sea.shared.types")
local Chartmeta = require("sea.chart.Chartmeta")
local Chartdiff = require("sea.chart.Chartdiff")
local ChartplayComputed = require("sea.chart.ChartplayComputed")
local Timings = require("sea.chart.Timings")
local Healths = require("sea.chart.Healths")

---@class sea.ComputeStageTimings
---@field replay_load number
---@field chart_parse number
---@field difficulty number
---@field replay number

---@class sea.ComputeResult
---@field version string
---@field chartmeta sea.Chartmeta
---@field chartdiff sea.Chartdiff
---@field default_chartdiff sea.Chartdiff?
---@field chartplay_computed sea.ChartplayComputed?
---@field timings sea.ComputeStageTimings
local ComputeResult = {}

local validate_timings = valid.struct({
	replay_load = types.number,
	chart_parse = types.number,
	difficulty = types.number,
	replay = types.number,
})

local validate_result = valid.struct({
	version = types.description,
	chartmeta = valid.struct(Chartmeta.struct),
	chartdiff = valid.struct(Chartdiff.struct),
	default_chartdiff = valid.optional(valid.struct(Chartdiff.struct)),
	chartplay_computed = valid.optional(valid.struct(ChartplayComputed.struct)),
	timings = validate_timings,
})

---@param result sea.ComputeResult
---@return true?
---@return string|valid.Errors?
function ComputeResult.validate(result)
	return validate_result(result)
end

---@param result sea.ComputeResult
---@return sea.ComputeResult
function ComputeResult.restore(result)
	setmetatable(result.chartmeta, Chartmeta)
	if result.chartmeta.timings then
		setmetatable(result.chartmeta.timings, Timings)
	end
	if result.chartmeta.healths then
		setmetatable(result.chartmeta.healths, Healths)
	end
	setmetatable(result.chartdiff, Chartdiff)
	if result.default_chartdiff then
		setmetatable(result.default_chartdiff, Chartdiff)
	end
	if result.chartplay_computed then
		setmetatable(result.chartplay_computed, ChartplayComputed)
	end
	return result
end

return ComputeResult
