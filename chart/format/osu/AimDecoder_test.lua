local TestChart = require("rizu.gameplay.modes.TestChart")
local ModeNotes = require("chart.model.ModeNotes")
local ChartDecoder = require("chart.format.osu.ChartDecoder")
local AimDecoder = require("chart.format.osu.AimDecoder")
local RefChart = require("chart.refchart.RefChart")
local SliderPath = require("chart.format.osu.SliderPath")
local SliderTiming = require("chart.format.osu.SliderTiming")
local Restorer = require("chart.refchart.Restorer")

local test = {}

local header = [[osu file format v14
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
]]

---@param t testing.T
function test.positions_settings_and_same_time_objects_survive_refchart(t)
	local chart = ChartDecoder():decode(header .. "100,192,1000,1,0,0:0:0:0:\n400,100,1000,1,0,0:0:0:0:")[1].chart
	local restored = Restorer():restore(RefChart(chart))
	t:eq(tostring(restored.inputMode), "1osu")
	t:tdeq(ModeNotes.read(restored, "osu"), ModeNotes.read(chart, "osu"))
	t:eq(#ModeNotes.read(restored, "osu").objects, 2)
	t:eq(ModeNotes.read(restored, "osu").objects[2].x, 400)
	t:eq(ModeNotes.read(restored, "osu").circle_size, 4)
	t:eq(ModeNotes.read(restored, "osu").approach_rate, 7)
	t:eq(ModeNotes.read(restored, "osu").overall_difficulty, 6)
	t:eq(AimDecoder.isSupported(restored), true)
end

---@param t testing.T
function test.unsupported_objects_are_preserved_and_rejected(t)
	for _, line in ipairs({
		"256,192,1000,128,0,2000:0:0:0:0:",
	}) do
		local chart = ChartDecoder():decode(header .. line)[1].chart
		t:eq(#ModeNotes.read(chart, "osu").objects, 1)
		local ok, err = AimDecoder.isSupported(chart)
		t:eq(ok, false)
		t:assert(err:find("unsupported object type", 1, true))
	end
end

---@param t testing.T
function test.slider_source_data_survives_refchart_without_placeholder_duration(t)
	local source = header:gsub("ApproachRate:7", "ApproachRate:7\nSliderMultiplier:1\nSliderTickRate:1")
	local chart = ChartDecoder():decode(source .. "100,192,1000,2,0,L|400:192,2,300")[1].chart
	local aim = ModeNotes.read(Restorer():restore(RefChart(chart)), "osu")
	t:tdeq(aim, ModeNotes.read(chart, "osu"))
	local slider = aim.objects[1].slider
	t:tdeq(slider.controls, {{100, 192}, {400, 192}})
	local path = SliderPath(slider.curve_type, slider.controls, slider.length)
	local timing = SliderTiming(aim.objects[1].time, path.length, slider.spans,
		aim.slider_multiplier, aim.slider_tick_rate, aim.timing_points, aim.format_version)
	t:eq(timing.end_time, 4)
	t:tdeq({path:position(timing:progress(2.5))}, {400, 192})
	t:tdeq({path:position(timing:progress(4))}, {100, 192})
	t:eq(AimDecoder.isSupported(TestChart.create(aim, "osu")), true)
end

---@param t testing.T
function test.legacy_format_version_is_preserved(t)
	local source = header:gsub("format v14", "format v7")
	local chart = ChartDecoder():decode(source .. "100,192,1000,1,0,0:0:0:0:")[1].chart
	t:eq(ModeNotes.read(chart, "osu").format_version, 7)
end

---@param t testing.T
function test.spinner_end_time_survives_refchart_and_is_validated(t)
	local chart = ChartDecoder():decode(header .. "256,192,1000,8,0,2500,0:0:0:0:")[1].chart
	local aim = ModeNotes.read(Restorer():restore(RefChart(chart)), "osu")
	t:eq(aim.objects[1].end_time, 2.5)
	t:eq(AimDecoder.isSupported(TestChart.create(aim, "osu")), true)
	for _, ending in ipairs({1, 0, math.huge, 0 / 0}) do
		aim.objects[1].end_time = ending
		t:eq(AimDecoder.isSupported(TestChart.create(aim, "osu")), false)
	end
	aim.objects[1].end_time = nil
	t:eq(AimDecoder.isSupported(TestChart.create(aim, "osu")), false)
end

---@param t testing.T
function test.stack_leniency_default_and_explicit_zero(t)
	local line = "100,192,1000,1,0,0:0:0:0:"
	local aim = ModeNotes.read(ChartDecoder():decode(header .. line)[1].chart, "osu")
	t:eq(aim.stack_leniency, 0.7)
	local explicit = header:gsub("Mode:0", "Mode:0\nStackLeniency:0")
	t:eq(ModeNotes.read(ChartDecoder():decode(explicit .. line)[1].chart, "osu").stack_leniency, 0)
	aim.stack_leniency = 2
	t:eq(AimDecoder.isSupported(TestChart.create(aim, "osu")), false)
end

return test
