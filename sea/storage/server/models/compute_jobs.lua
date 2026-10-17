local stbl = require("stbl")
local ComputeJob = require("sea.compute.ComputeJob")
local ComputeJobState = require("sea.compute.ComputeJobState")
local Chartdiff = require("sea.chart.Chartdiff")

---@class sea.ChartdiffPayload
local ChartdiffPayload = {}

---@param chartdiff sea.Chartdiff
---@return string
function ChartdiffPayload.encode(chartdiff)
	return stbl.encode(chartdiff)
end

---@param value string
---@return sea.Chartdiff
function ChartdiffPayload.decode(value)
	local chartdiff = stbl.decode(value)
	setmetatable(chartdiff, Chartdiff)
	return chartdiff
end

---@type rdb.ModelOptions
local compute_jobs = {}

compute_jobs.metatable = ComputeJob
compute_jobs.types = {
	state = ComputeJobState,
	chartdiff = ChartdiffPayload,
}

return compute_jobs
