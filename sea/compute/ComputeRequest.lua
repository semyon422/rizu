local valid = require("valid")
local types = require("sea.shared.types")
local Chartplay = require("sea.chart.Chartplay")
local Chartdiff = require("sea.chart.Chartdiff")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")

---@class sea.ComputeRequest
---@field version string
---@field chartplay sea.Chartplay
---@field chartdiff sea.Chartdiff
---@field chart_name string
---@field chart_data string
---@field replay_data string
local ComputeRequest = {}

local validate_request = valid.struct({
	version = types.description,
	chartplay = valid.compose(valid.struct(Chartplay.struct), require("sea.chart.types").subtimings_pair),
	chartdiff = function(value) return type(value) == "table" end,
	chart_name = types.description,
	chart_data = function(value) return type(value) == "string" end,
	replay_data = function(value) return type(value) == "string" end,
})

local function restore_chartplay(chartplay)
	setmetatable(chartplay, Chartplay)
	if chartplay.timings then
		setmetatable(chartplay.timings, Timings)
	end
	if chartplay.subtimings then
		setmetatable(chartplay.subtimings, Subtimings)
	end
	if chartplay.healths then
		setmetatable(chartplay.healths, Healths)
	end
end

local function restore_chartdiff(chartdiff)
	setmetatable(chartdiff, Chartdiff)
end

---@param request sea.ComputeRequest
---@return true?
---@return string|valid.Errors?
function ComputeRequest.validate(request)
	local ok, err = validate_request(request)
	if not ok then
		return nil, err
	end
	if request.chartplay.custom then
		return valid.struct(Chartdiff.struct)(request.chartdiff)
	end
	return true
end

---@param request sea.ComputeRequest
---@return sea.ComputeRequest
function ComputeRequest.restore(request)
	restore_chartplay(request.chartplay)
	restore_chartdiff(request.chartdiff)
	return request
end

return ComputeRequest
