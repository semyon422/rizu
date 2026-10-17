local FakeClient = require("sea.compute.FakeClient")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@param t testing.T
function test.all(t)
	local chartfile_name = "chart.sph"
	local chartfile_data = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0
0100
0010
0001
1000
0100
0010
0001
1000
0100
0010
0001
1000
0100
0010
0001
1000 =4
]]

	local client = FakeClient(0.02, 8)

	local replayBase = client.replayBase

	replayBase.timing_values = assert(TimingValuesFactory:get(Timings("sphere")))
	--
	replayBase.modifiers = {}
	replayBase.rate = 1
	replayBase.mode = "mania"
	--
	replayBase.nearest = true
	replayBase.tap_only = false
	replayBase.timings = Timings("osuod", 8)
	replayBase.subtimings = Subtimings("scorev", 1)
	replayBase.healths = nil
	replayBase.columns_order = {4, 1, 2, 3}
	--
	replayBase.custom = false
	replayBase.const = false
	replayBase.rate_type = "linear"

	local ret, err = client:play(chartfile_name, chartfile_data, 1, 0, 0)
	if not t:assert(ret, err) then
		return
	end
	---@cast ret -?

	t:assert(ret.chartplay:equalsChartplayBase(replayBase))
	t:tdeq(ret.chartplay.judges, {10, 5, 0, 0, 0, 2})
end

return test
