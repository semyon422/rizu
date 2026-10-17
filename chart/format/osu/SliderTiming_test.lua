local SliderTiming = require("chart.format.osu.SliderTiming")
local test = {}

---@param t testing.T
function test.duration_ticks_repeats_and_tail(t)
	local timing = SliderTiming(1, 300, 2, 1, 1, {{offset = 0, beatLength = 500}}, 14)
	t:eq(timing.span_duration, 1.5)
	t:eq(timing.end_time, 4)
	t:tdeq(timing.checkpoints, {
		{time = 1.5, progress = 1 / 3, kind = "tick"},
		{time = 2, progress = 2 / 3, kind = "tick"},
		{time = 2.5, progress = 1, kind = "repeat"},
		{time = 3, progress = 2 / 3, kind = "tick"},
		{time = 3.5, progress = 1 / 3, kind = "tick"},
		{time = 4, progress = 0, kind = "tail"},
	})
	t:eq(timing:progress(0), 0)
	t:eq(timing:progress(2.5), 1)
	t:eq(timing:progress(3.25), 0.5)
	t:eq(timing:progress(5), 0)
end

---@param t testing.T
function test.inherited_velocity_is_sampled_at_head_and_red_resets_it(t)
	local points = {
		{offset = 0, beatLength = 500},
		{offset = 1000, beatLength = -50},
		{offset = 1500, beatLength = 1000},
	}
	local fast = SliderTiming(1, 400, 1, 1, 1, points, 14)
	t:eq(fast.span_duration, 1)
	t:eq(fast.end_time, 2)
	t:eq(#fast.checkpoints, 2)
	local slow = SliderTiming(1.5, 400, 1, 1, 1, points, 14)
	t:eq(slow.span_duration, 4)
	local legacy = SliderTiming(1, 400, 1, 1, 1, points, 7)
	t:eq(#legacy.checkpoints, 4)
end

---@param t testing.T
function test.short_sliders_and_budgets(t)
	local short = SliderTiming(0, 1, 1, 1, 1, {}, 14)
	t:eq(#short.checkpoints, 1)
	t:eq(short.checkpoints[1].kind, "tail")
	t:has_error(function() SliderTiming(0, 0, 1, 1, 1, {}, 14) end)
	t:has_error(function() SliderTiming(0, 100, 1.5, 1, 1, {}, 14) end)
	t:has_error(function() SliderTiming(0, 1e9, 9000, 1, 100, {}, 14) end)
end

---@param t testing.T
function test.reverse_spans_revisit_the_same_tick_positions(t)
	local timing = SliderTiming(0, 250, 2, 1, 1, {}, 14)
	t:eq(timing.checkpoints[4].progress, 0.8)
	t:eq(timing.checkpoints[4].time, 1.5)
	t:eq(timing.checkpoints[5].progress, 0.4)
	t:eq(timing.checkpoints[5].time, 2)
end

return test
