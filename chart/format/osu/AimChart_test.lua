local ChartDecoder = require("chart.format.osu.ChartDecoder")
local AimChart = require("chart.format.osu.AimChart")
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
	t:tdeq(restored.aim, chart.aim)
	t:eq(#restored.aim.objects, 2)
	t:eq(restored.aim.objects[2].x, 400)
	t:eq(restored.aim.circle_size, 4)
	t:eq(restored.aim.approach_rate, 7)
	t:eq(restored.aim.overall_difficulty, 6)
	t:eq(AimChart.isSupported(restored.aim), true)
end

---@param t testing.T
function test.unsupported_objects_are_preserved_and_rejected(t)
	for _, line in ipairs({
		"256,192,1000,128,0,2000:0:0:0:0:",
	}) do
		local chart = ChartDecoder():decode(header .. line)[1].chart
		t:eq(#chart.aim.objects, 1)
		local ok, err = AimChart.isSupported(chart.aim)
		t:eq(ok, false)
		t:assert(err:find("unsupported object type", 1, true))
	end
end

---@param t testing.T
function test.slider_source_data_survives_refchart_without_placeholder_duration(t)
	local source = header:gsub("ApproachRate:7", "ApproachRate:7\nSliderMultiplier:1\nSliderTickRate:1")
	local chart = ChartDecoder():decode(source .. "100,192,1000,2,0,L|400:192,2,300")[1].chart
	local aim = Restorer():restore(RefChart(chart)).aim
	t:tdeq(aim, chart.aim)
	local slider = aim.objects[1].slider
	t:tdeq(slider.controls, {{100, 192}, {400, 192}})
	local path = SliderPath(slider.curve_type, slider.controls, slider.length)
	local timing = SliderTiming(aim.objects[1].time, path.length, slider.spans,
		aim.slider_multiplier, aim.slider_tick_rate, aim.timing_points, aim.format_version)
	t:eq(timing.end_time, 4)
	t:tdeq({path:position(timing:progress(2.5))}, {400, 192})
	t:tdeq({path:position(timing:progress(4))}, {100, 192})
	t:eq(AimChart.isSupported(aim), true)
end

---@param t testing.T
function test.legacy_format_version_is_preserved(t)
	local source = header:gsub("format v14", "format v7")
	local chart = ChartDecoder():decode(source .. "100,192,1000,1,0,0:0:0:0:")[1].chart
	t:eq(chart.aim.format_version, 7)
end

---@param t testing.T
function test.spinner_end_time_survives_refchart_and_is_validated(t)
	local chart = ChartDecoder():decode(header .. "256,192,1000,8,0,2500,0:0:0:0:")[1].chart
	local aim = Restorer():restore(RefChart(chart)).aim
	t:eq(aim.objects[1].end_time, 2.5)
	t:eq(AimChart.isSupported(aim), true)
	for _, ending in ipairs({1, 0, math.huge, 0 / 0}) do
		aim.objects[1].end_time = ending
		t:eq(AimChart.isSupported(aim), false)
	end
	aim.objects[1].end_time = nil
	t:eq(AimChart.isSupported(aim), false)
end

return test
