local Tracking = require("rizu.gameplay.aim.Tracking")
local SliderTiming = require("chart.format.osu.SliderTiming")
local test = {}

---@param t testing.T
function test.tail_does_not_precede_final_span_midpoint_or_ticks(t)
	local short = SliderTiming(1, 4, 1, 1, 1, {}, 14)
	t:aeq(Tracking.tailTime(short), 1.01, 1e-9)
	local repeated = SliderTiming(1, 4, 2, 1, 1, {}, 14)
	t:aeq(Tracking.tailTime(repeated), 1.03, 1e-9)
	local dense = SliderTiming(0, 100, 1, 1, 20, {}, 14)
	t:aeq(Tracking.tailTime(dense), 0.475, 1e-9)
end

---@param t testing.T
function test.tracking_allocation_is_bounded(t)
	local timing = SliderTiming(0, 1000000, 1, 1, 0.0001, {}, 14)
	t:has_error(function() Tracking.validateBudget({{timing = timing}}) end)
end

return test
