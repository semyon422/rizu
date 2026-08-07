local table_util = require("table_util")
local Chartplay = require("sea.chart.Chartplay")
local Chartdiff = require("sea.chart.Chartdiff")
local FakeClient = require("sea.compute.FakeClient")
local ReplayComputer = require("sea.compute.ReplayComputer")
local chart_samples = require("sea.chart.samples.Samples")

local test = {}

local function create_request()
	local sample = chart_samples[1]
	local client = FakeClient(0.02, 100)
	local play = client:play(sample.name, sample.data, 1, 100, 0)
	local chartplay = setmetatable(table_util.sub(play.chartplay, table_util.keys(Chartplay.struct)), Chartplay)
	local chartdiff = setmetatable(table_util.sub(play.chartdiff, table_util.keys(Chartdiff.struct)), Chartdiff)
	return {
		version = "test-version",
		chartplay = chartplay,
		chartdiff = chartdiff,
		chart_name = sample.name,
		chart_data = sample.data,
		replay_data = play.replay_data,
	}, play
end

---@param t testing.T
function test.computes_canonical_result(t)
	local request, play = create_request()
	local result = assert(ReplayComputer():compute(request))
	t:eq(result.version, request.version)
	t:assert(result.chartmeta:equalsComputed(play.chartmeta))
	t:assert(result.chartdiff:equalsComputed(play.chartdiff))
	t:assert(result.chartplay_computed:equalsComputed(play.chartplay, true))
	t:assert(result.timings.chart_parse >= 0)
	t:assert(result.timings.difficulty >= 0)
	t:assert(result.timings.replay >= 0)
end

---@param t testing.T
function test.rejects_hash_mismatch(t)
	local request = create_request()
	request.chart_data = request.chart_data .. "\n"
	local result, err = ReplayComputer():compute(request)
	t:eq(result, nil)
	t:eq(err, "chart hash mismatch")
end

return test
