local SliderPath = require("chart.format.osu.SliderPath")
local SliderTiming = require("chart.format.osu.SliderTiming")

local Sliders = {}

---@class rizu.aim.Slider
---@field path chart.osu.SliderPath
---@field timing chart.osu.SliderTiming
---@field tail_time number
---@field tracking_broken boolean?
---@field intact boolean

---@param chart chart.osu.AimChart
---@return {[integer]: rizu.aim.Slider}
function Sliders.prepare(chart)
	---@type {[integer]: rizu.aim.Slider}
	local sliders = {}
	for i, object in ipairs(chart.objects) do
		if object.kind == "slider" then
			local source = assert(object.slider, "Aim prototype: missing slider data.")
			local path = SliderPath(source.curve_type, source.controls, source.length)
			local timing = SliderTiming(object.time, path.length, source.spans,
				chart.slider_multiplier, chart.slider_tick_rate, chart.timing_points, chart.format_version)
			sliders[i] = {path = path, timing = timing, intact = true, tail_time = timing.end_time}
		end
	end
	return sliders
end

return Sliders
