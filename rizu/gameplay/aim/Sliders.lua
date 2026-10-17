local Objects = require("chart.format.osu.Objects")
local SliderPath = require("chart.format.osu.SliderPath")
local SliderTiming = require("chart.format.osu.SliderTiming")

local Sliders = {}

---@class rizu.aim.Slider
---@field path chart.osu.SliderPath
---@field timing chart.osu.SliderTiming
---@field tail_time number
---@field tracking_broken boolean?
---@field intact boolean

---@param chart chart.Chart
---@return {[integer]: rizu.aim.Slider}
function Sliders.prepare(chart)
	---@type {[integer]: rizu.aim.Slider}
	local sliders = {}
	for i, object in ipairs(Objects.get(chart, "osu")) do
		if object.kind == "slider" then
			local source = assert(object.slider, "Aim prototype: missing slider data.")
			local path = SliderPath(source.curve_type, source.controls, source.length)
			local timing = SliderTiming(object.time, path.length, source.spans,
				chart.data.slider_multiplier, chart.data.slider_tick_rate, chart.data.timing_points, chart.data.format_version)
			sliders[i] = {path = path, timing = timing, intact = true, tail_time = timing.end_time}
		end
	end
	return sliders
end

return Sliders
