local GameplayChart = require("rizu.gameplay.GameplayChart")
local ReplayBase = require("sea.replays.ReplayBase")
local Restorer = require("chart.refchart.Restorer")
local RawOsu = require("chart.format.osu.RawOsu")
local Osu = require("chart.format.osu.Osu")
local TaikoChart = require("chart.format.osu.TaikoChart")
local test = {}

local data = [[osu file format v14
[General]
Mode:1
[Difficulty]
CircleSize:5
OverallDifficulty:5
SliderMultiplier:1.4
SliderTickRate:1
[TimingPoints]
0,500,4,1,0,100,1,0
1500,-50,4,1,0,100,0,0
[HitObjects]
256,192,1000,1,0,0:0:0:0:
256,192,1000,1,6,0:0:0:0:
256,192,2000,2,0,L|356:192,2,280
256,192,4000,8,0,5000,0:0:0:0:
]]

---@param source string
---@return chart.osu.TaikoChart
local function decode(source)
	local raw = RawOsu()
	raw:decode(source)
	local osu = Osu(raw)
	osu:decode()
	return TaikoChart(osu)
end

---@param t testing.T
function test.native_objects_preserve_color_size_and_intervals(t)
	local chart = decode(data)
	t:eq(#chart.objects, 4)
	t:eq(chart.objects[1].color, "don")
	t:eq(chart.objects[2].color, "kat")
	t:eq(chart.objects[2].big, true)
	t:eq(chart.objects[1].time, chart.objects[2].time)
	t:eq(chart.objects[3].kind, "roll")
	t:eq(chart.objects[3].end_time, 3)
	t:eq(chart.objects[3].target, 4)
	t:eq(chart.objects[4].kind, "spinner")
	t:eq(chart.objects[4].end_time, 5)
	t:eq(chart.objects[4].target, 5)
end

---@param t testing.T
function test.reject_conversion_and_invalid_intervals(t)
	t:has_error(function() decode((data:gsub("Mode:1", "Mode:0"))) end)
	t:has_error(function() decode((data:gsub("5000,0:0:0:0:", "4000,0:0:0:0:"))) end)
end

---@param t testing.T
function test.worker_snapshot_keeps_native_mode_and_bounds(t)
	local compute = assert(loadstring(string.dump(GameplayChart.compute)))
	local result = compute({chartfile_name = "native.osu", index = 1}, data, nil, ReplayBase(), {})
	t:eq(result.error, nil)
	t:eq(result.chartmeta.inputmode, "1taiko")
	t:eq(result.chartdiff.inputmode, "1taiko")
	t:eq(result.chartdiff.duration, 4)
	t:eq(result.chartdiff.osu_diff, nil)
	local restored = Restorer():restore(result.refchart)
	t:tdeq(restored.taiko, decode(data))
	local base = ReplayBase()
	base.tap_only = true
	t:assert(compute({chartfile_name = "native.osu", index = 1}, data, nil, base, {}).error)
end

return test
