local CircleRules = require("rizu.gameplay.aim.CircleRules")
local Stacking = require("rizu.gameplay.aim.Stacking")
local Sliders = require("rizu.gameplay.aim.Sliders")
local table_util = require("table_util")
local test = {}

---@return chart.osu.AimChart
local function chart()
	return {circle_size = 5, approach_rate = 5, overall_difficulty = 5, stack_leniency = 0.7,
		format_version = 14, slider_multiplier = 1, slider_tick_rate = 1,
		timing_points = {{offset = 0, beatLength = 500}}, objects = {
			{time = 1, x = 100, y = 100, kind = "circle", sounds = {}},
			{time = 1.2, x = 100, y = 100, kind = "circle", sounds = {}},
			{time = 1.4, x = 100, y = 100, kind = "circle", sounds = {}},
		}}
end

---@param t testing.T
function test.circle_stack_preserves_source_and_legacy_geometry(t)
	local aim = chart()
	local original = table_util.deepcopy(aim)
	local rules = CircleRules(aim)
	t:tdeq(aim, original)
	t:eq(rules.chart.objects[1].stack_height, 2)
	t:aeq(rules.chart.objects[1].x, 93.6, 1e-9)
	t:eq(rules.chart.objects[3].x, 100)
	local legacy = CircleRules(aim, false)
	t:eq(legacy.chart.objects[1].x, 100)
	for _, frame in ipairs(CircleRules.autoplay(aim)) do rules:receive(frame.event, frame.time) end
	rules:update(5)
	t:eq(rules.hits, 3)
	local again = CircleRules(aim)
	t:eq(again.chart.objects[1].x, rules.chart.objects[1].x)
end

---@param t testing.T
function test.slider_tail_negative_stack_and_repeat_parity(t)
	local aim = chart()
	aim.objects[1].kind = "slider"
	aim.objects[1].slider = {curve_type = "L", controls = {{100, 100}, {200, 100}}, length = 100, spans = 1}
	aim.objects[2].time, aim.objects[3].time = 1.6, 1.8
	aim.objects[2].x, aim.objects[3].x = 200, 200
	local rules = CircleRules(aim)
	t:eq(rules.chart.objects[1].stack_height, 0)
	t:eq(rules.chart.objects[2].stack_height, -1)
	t:eq(rules.chart.objects[3].stack_height, -2)
	t:aeq(rules.chart.objects[2].x, 203.2, 1e-9)
	aim.objects[1].slider.spans = 2
	rules = CircleRules(aim)
	t:eq(rules.chart.objects[2].stack_height, 1)
	t:eq(rules.chart.objects[3].stack_height, 0)
end

---@param t testing.T
function test.slider_body_and_head_translate_together(t)
	local aim = chart()
	aim.objects[1].kind = "slider"
	aim.objects[1].slider = {curve_type = "L", controls = {{100, 100}, {200, 100}}, length = 100, spans = 1}
	local rules = CircleRules(aim)
	local object = rules.chart.objects[1]
	t:eq(object.stack_height, 2)
	t:eq(object.slider.controls[1][1], object.x)
	local x, y = rules.sliders[1].path:position(0)
	t:eq(x, object.x)
	t:eq(y, object.y)
	t:eq(aim.objects[1].slider.controls[1][1], 100)
end

---@param t testing.T
function test_distance_time_spinner_exclusion_and_old_format(t)
	local aim = chart()
	aim.objects[2].x = 103
	aim.objects[3].time = 3
	local rules = CircleRules(aim)
	t:eq(rules.chart.objects[1].stack_height, 0)
	aim = chart()
	aim.objects[2].kind, aim.objects[2].end_time = "spinner", 1.3
	rules = CircleRules(aim)
	t:eq(rules.chart.objects[2].stack_height, 0)
	t:eq(rules.chart.objects[1].stack_height, 1)
	aim = chart()
	aim.format_version = 5
	rules = CircleRules(aim)
	t:eq(rules.chart.objects[1].stack_height, 2)
	t:eq(rules.chart.objects[2].stack_height, 1)
end

---@param t testing.T
function test.no_cumulative_translation(t)
	local aim = chart()
	local a = Stacking.apply(aim, Sliders.prepare(aim), 1.2, 32)
	local b = Stacking.apply(aim, Sliders.prepare(aim), 1.2, 32)
	t:tdeq(a, b)
end

return test
