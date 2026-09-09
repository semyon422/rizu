local class = require("class")

---@class chart.osu.SliderControlPoint
---@field offset number Milliseconds.
---@field beatLength number Milliseconds; negative values encode inherited velocity.

---@class chart.osu.SliderCheckpoint
---@field time number Seconds.
---@field progress number Position along the path, including reverse spans.
---@field kind "tick"|"repeat"|"tail"

---@class chart.osu.SliderTiming
---@operator call: chart.osu.SliderTiming
---@field checkpoints chart.osu.SliderCheckpoint[]
local SliderTiming = class()

---@param start_time number Seconds.
---@param length number Pixels per span.
---@param spans integer osu! repeatCount is the total span count.
---@param multiplier number
---@param tick_rate number
---@param points chart.osu.SliderControlPoint[] Sorted timing points.
---@param format_version integer
function SliderTiming:new(start_time, length, spans, multiplier, tick_rate, points, format_version)
	assert(start_time == start_time and math.abs(start_time) < math.huge, "invalid slider start time")
	assert(length > 0 and length < math.huge, "invalid slider length")
	assert(spans >= 1 and spans <= 9000 and spans == math.floor(spans), "invalid slider span count")
	assert(multiplier > 0 and multiplier < math.huge and tick_rate > 0 and tick_rate < math.huge, "invalid slider difficulty")
	local beat_length, velocity = 500, 1
	for _, point in ipairs(points) do
		if point.offset > start_time * 1000 then break end
		if point.beatLength > 0 then
			beat_length, velocity = point.beatLength, 1
		elseif point.beatLength < 0 then
			velocity = math.min(10, math.max(0.1, -100 / point.beatLength))
		end
	end
	self.start_time = start_time
	self.spans = spans
	self.velocity = 100 * multiplier * velocity / (beat_length / 1000)
	self.span_duration = length / self.velocity
	self.end_time = start_time + self.span_duration * spans
	assert(self.span_duration > 0 and self.end_time < math.huge, "invalid slider duration")
	local tick_distance = 100 * multiplier * velocity / tick_rate
	if format_version < 8 then tick_distance = tick_distance / velocity end
	self.checkpoints = {}
	local tick_count = math.max(0, math.ceil((length - self.velocity * 0.01) / tick_distance) - 1)
	assert((tick_count + 1) * spans <= 16384, "slider checkpoint budget exceeded")
	for span = 1, spans do
		local reverse = span % 2 == 0
		for tick = 1, tick_count do
			local progress = (reverse and tick_count - tick + 1 or tick) * tick_distance / length
			local traversal = reverse and 1 - progress or progress
			self.checkpoints[#self.checkpoints + 1] = {
				time = start_time + (span - 1 + traversal) * self.span_duration,
				progress = progress,
				kind = "tick",
			}
		end
		self.checkpoints[#self.checkpoints + 1] = {
			time = start_time + span * self.span_duration,
			progress = reverse and 0 or 1,
			kind = span == spans and "tail" or "repeat",
		}
	end
end

---@param time number Seconds.
---@return number
function SliderTiming:progress(time)
	local elapsed = math.max(0, math.min(self.spans, (time - self.start_time) / self.span_duration))
	local span = math.min(self.spans - 1, math.floor(elapsed))
	local progress = elapsed - span
	return span % 2 == 1 and 1 - progress or progress
end

return SliderTiming
