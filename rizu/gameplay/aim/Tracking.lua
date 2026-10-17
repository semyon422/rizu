local Tracking = {}

Tracking.step = 1 / 240
Tracking.tail_leniency = 0.036

---@param timing chart.osu.SliderTiming
---@return number
function Tracking.tailTime(timing)
	local final_span_start = timing.end_time - timing.span_duration
	local time = math.max(final_span_start + timing.span_duration / 2, timing.end_time - Tracking.tail_leniency)
	-- Never reorder the tail before an actual tick or repeat.
	for _, checkpoint in ipairs(timing.checkpoints) do
		if checkpoint.kind ~= "tail" then time = math.max(time, checkpoint.time) end
	end
	return time
end

---@param sliders {[integer]: rizu.aim.Slider}
function Tracking.validateBudget(sliders)
	local count = 0
	for _, slider in pairs(sliders) do
		count = count + math.ceil((Tracking.tailTime(slider.timing) - slider.timing.start_time) / Tracking.step)
			+ #slider.timing.checkpoints + 2
	end
	assert(count < 250000, "Aim prototype: slider tracking budget exceeded.")
end

return Tracking
