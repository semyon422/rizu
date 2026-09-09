local Preparation = require("rizu.gameplay.aim.Preparation")
local RefChart = require("chart.refchart.RefChart")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local Settings = require("rizu.config.Settings")
local ReplayBase = require("sea.replays.ReplayBase")
local ComputeContext = require("sea.compute.ComputeContext")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

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
1000 =4
]]

---@param t testing.T
function test.all(t)
	local fs = FakeFilesystem()
	local settings = Settings.createConfig(fs)

	local dir = "chart_set"
	local chartview = {
		location_dir = dir,
		location_path = dir .. "/" .. chartfile_name,
		chartfile_name = chartfile_name,
		index = 1,
	}

	fs:createDirectory(dir)
	fs:write(chartview.location_path, chartfile_data)

	local gl = GameplayChart(settings, fs, chartview)

	gl:load(ReplayBase(), ComputeContext())
end

---@param t testing.T
function test.aim_skips_mania_compute_and_survives_worker_snapshot(t)
	local fs = FakeFilesystem()
	local settings = Settings.createConfig(fs)
	local data = [[osu file format v14
[General]
Mode:0
PreviewTime:0
[Difficulty]
CircleSize:4
OverallDifficulty:6
ApproachRate:7
[TimingPoints]
0,500,4,2,0,70,1,0
[HitObjects]
100,192,1000,1,0,0:0:0:0:
400,100,1000,1,0,0:0:0:0:
]]
	local loader = GameplayChart(settings, fs, {chartfile_name = "circles.osu", index = 1})
	local base, ctx = ReplayBase(), ComputeContext()
	ctx.computeBase = function() error("mania compute must not run") end
	loader:loadPrepared(base, ctx, data)
	t:eq(ctx.chartdiff.mode, "osu")
	t:eq(ctx.chartdiff.start_time, 1)
	t:eq(ctx.chartdiff.osu_diff, nil)
	local restored = ComputeContext()
	loader:applyComputed(base, restored, {
		refchart = RefChart(ctx.chart), chartmeta = ctx.chartmeta, chartdiff = ctx.chartdiff,
		state = ctx.state, simplified_notes = {}, replay_base = {modifiers = {}},
	})
	t:tdeq(restored.chart.aim, ctx.chart.aim)
	t:eq(#restored.chart.aim.objects, 2)
end

---@param t testing.T
function test.slider_bounds_include_tail_and_invalid_geometry_is_rejected(t)
	local base, ctx = ReplayBase(), ComputeContext()
	local fs = FakeFilesystem()
	local loader = GameplayChart(Settings.createConfig(fs), fs, {chartfile_name = "sliders.osu", index = 1})
	loader:loadPrepared(base, ctx, [[osu file format v14
[General]
Mode:0
[Difficulty]
CircleSize:4
OverallDifficulty:5
SliderMultiplier:1
SliderTickRate:1
[TimingPoints]
0,500,4,2,0,70,1,0
[HitObjects]
100,100,1000,2,0,L|400:100,2,300
200,200,2000,1,0,0:0:0:0:
]])
	t:eq(ctx.chartdiff.start_time, 1)
	t:eq(ctx.chartdiff.duration, 3)
	t:eq(ctx.chartdiff.osu_diff, nil)
	ctx.chart.aim.objects[1].slider.length = 0
	t:has_error(function() Preparation.compute(ctx, base) end)
end

---@param t testing.T
function test.spinner_bounds_include_end_and_invalid_duration_is_rejected(t)
	local base, ctx = ReplayBase(), ComputeContext()
	local fs = FakeFilesystem()
	local loader = GameplayChart(Settings.createConfig(fs), fs, {chartfile_name = "spinner.osu", index = 1})
	loader:loadPrepared(base, ctx, [[osu file format v14
[General]
Mode:0
[Difficulty]
CircleSize:4
OverallDifficulty:5
[TimingPoints]
0,500,4,2,0,70,1,0
[HitObjects]
256,192,1000,8,0,5000,0:0:0:0:
]])
	t:eq(ctx.chartdiff.start_time, 1)
	t:eq(ctx.chartdiff.duration, 4)
	t:eq(ctx.chartdiff.osu_diff, nil)
	ctx.chart.aim.objects[1].end_time = 0
	t:has_error(function() Preparation.compute(ctx, base) end)
end

---@param t testing.T
function test.worker_decode_errors_are_returned_not_thrown(t)
	local data = [[osu file format v14
[General]
Mode:0
SampleSet:Invalid
[Difficulty]
CircleSize:4
OverallDifficulty:5
[TimingPoints]
0,500,4,1,0,100,1,0
[HitObjects]
100,100,1000,1,0,0:0:0:0:
]]
	-- Exercise the same dumped, upvalue-free entry point used by thread.async.
	local compute = assert(loadstring(string.dump(GameplayChart.compute)))
	local config = {tempoFactor = "primary", primaryTempo = 120, autoKeySound = false, swapVelocityType = false}
	local view = {chartfile_name = "test.osu", index = 1}
	local result = compute(view, data, nil, ReplayBase(), config)
	t:assert(result.error:find("invalid general sample set", 1, true))
	local valid = compute(view, data:gsub("SampleSet:Invalid", "SampleSet: None"), nil, ReplayBase(), config)
	t:eq(valid.error, nil)
	t:eq(valid.refchart.aim.sample_set, 1)
	view.index = 999
	local invalid_index = compute(view, data:gsub("SampleSet:Invalid", "SampleSet: None"), nil, ReplayBase(), config)
	t:eq(type(invalid_index.error), "string")
end

---@param t testing.T
function test.catch_worker_preparation_skips_mania_scoring(t)
	local data = [[osu file format v14
[General]
Mode:2
[Difficulty]
CircleSize:5
OverallDifficulty:5
[TimingPoints]
0,500,4,1,0,100,1,0
[HitObjects]
100,100,1000,1,0,0:0:0:0:
100,100,2000,2,0,L|300:100,1,200
]]
	local compute = assert(loadstring(string.dump(GameplayChart.compute)))
	local result = compute({chartfile_name = "catch.osu", index = 1}, data, nil, ReplayBase(), {})
	t:eq(result.error, nil)
	t:eq(result.chartdiff.inputmode, "1fruits")
	t:eq(result.chartdiff.osu_diff, nil)
	t:aeq(result.chartdiff.duration, 1 + 200 / 280, 1e-9)
	t:assert(result.refchart.catch)
end

return test
