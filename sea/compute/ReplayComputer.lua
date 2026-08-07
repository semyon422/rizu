local class = require("class")
local digest = require("digest")
local valid = require("valid")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local ComputeContext = require("sea.compute.ComputeContext")
local ComputeRequest = require("sea.compute.ComputeRequest")
local ComputeResult = require("sea.compute.ComputeResult")
local ReplayBase = require("sea.replays.ReplayBase")
local ReplayLoader = require("sea.replays.ReplayLoader")

---@class sea.ReplayComputer
---@operator call: sea.ReplayComputer
local ReplayComputer = class()

---@param request sea.ComputeRequest
---@param clock (fun(): number)?
---@return sea.ComputeResult?
---@return string?
function ReplayComputer:compute(request, clock)
	local ok, err = valid.format(ComputeRequest.validate(request))
	if not ok then
		return nil, "invalid request: " .. err
	end
	if digest.hash("md5", request.chart_data, true) ~= request.chartplay.hash then
		return nil, "chart hash mismatch"
	end
	if digest.hash("md5", request.replay_data, true) ~= request.chartplay.replay_hash then
		return nil, "replay hash mismatch"
	end

	clock = clock or os.clock
	local started = clock()
	local replay
	replay, err = ReplayLoader.load(request.replay_data)
	if not replay then
		return nil, "load replay: " .. err
	end
	local replay_load = clock() - started

	local chartplay = request.chartplay
	local equal
	equal, err = replay:equalsChartplayBase(chartplay)
	if not equal then
		return nil, "chartplay base of replay differs: " .. err
	end
	equal, err = replay:equalsChartmetaKey(chartplay)
	if not equal then
		return nil, "chartmeta key of replay differs: " .. err
	end

	local ctx = ComputeContext()
	started = clock()
	local chart_chartmeta
	chart_chartmeta, err = ctx:fromFileData(request.chart_name, request.chart_data, chartplay.index)
	if not chart_chartmeta then
		return nil, "from file data: " .. err
	end
	local chart_parse = clock() - started
	local chartmeta = chart_chartmeta.chartmeta

	local timings = chartplay.timings or chartmeta.timings
	if not timings then
		return nil, "missing timings"
	end
	if timings.name ~= "arbitrary" then
		local timing_values = TimingValuesFactory:get(timings, chartplay.subtimings)
		if not timing_values then
			return nil, "invalid timings-subtimings pair"
		elseif not timing_values:equals(replay.timing_values) then
			return nil, "timing values differs"
		end
	end

	started = clock()
	local default_chartdiff
	if #chartplay.modifiers > 0 or chartplay.rate ~= 1 then
		default_chartdiff = ctx:computeBase(ReplayBase())
	end

	local chartdiff
	local chartplay_computed
	local replay_time = 0
	if chartplay.custom then
		chartdiff = request.chartdiff
	else
		ctx:applyModifierReorder(replay)
		chartdiff = ctx:computeBase(replay)
	end
	local difficulty = clock() - started

	if not chartplay.custom then
		started = clock()
		chartplay_computed, err = ctx:computeReplay(replay)
		if not chartplay_computed then
			return nil, "compute replay: " .. err
		end
		replay_time = clock() - started
	end

	---@type sea.ComputeResult
	local result = {
		version = request.version,
		chartmeta = chartmeta,
		chartdiff = chartdiff,
		default_chartdiff = default_chartdiff,
		chartplay_computed = chartplay_computed,
		timings = {
			replay_load = replay_load,
			chart_parse = chart_parse,
			difficulty = difficulty,
			replay = replay_time,
		},
	}

	ok, err = valid.format(ComputeResult.validate(result))
	if not ok then
		return nil, "invalid result: " .. err
	end
	return result
end

return ReplayComputer
