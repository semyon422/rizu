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

return test
