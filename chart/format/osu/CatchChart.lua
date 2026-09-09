local class = require("class")
local AimChart = require("chart.format.osu.AimChart")
local SliderPath = require("chart.format.osu.SliderPath")
local SliderTiming = require("chart.format.osu.SliderTiming")

---@class chart.osu.CatchObject
---@field order integer? Temporary stable sort key.
---@field time number
---@field x number
---@field kind "fruit"|"droplet"|"tiny"|"banana"
---@field sounds {[1]: string, [2]: number}[]

---@class chart.osu.CatchChart
---@operator call: chart.osu.CatchChart
---@field objects chart.osu.CatchObject[]
local CatchChart = class()

---@param osu chart.osu.Osu
function CatchChart:new(osu)
	-- Share the native osu source reader, not an Aim-to-Catch gameplay conversion.
	local source = AimChart(osu)
	local ok, err = AimChart.isSupported(source)
	assert(ok, err)
	self.circle_size, self.approach_rate = source.circle_size, source.approach_rate
	self.objects = {}
	local seed = 1337
	local order = 0
	---@param time number
	---@param x number
	---@param kind "fruit"|"droplet"|"tiny"|"banana"
	---@param sounds {[1]: string, [2]: number}[]
	local function add(time, x, kind, sounds)
		assert(#self.objects < 100000, "Catch prototype: object budget exceeded.")
		order = order + 1
		self.objects[#self.objects + 1] = {time = time, x = math.max(0, math.min(512, x)), kind = kind, sounds = sounds, order = order}
	end
	for _, object in ipairs(source.objects) do
		if object.kind == "circle" then
			add(object.time, object.x, "fruit", object.sounds)
		elseif object.kind == "slider" then
			local slider = assert(object.slider)
			local path = SliderPath(slider.curve_type, slider.controls, slider.length)
			local timing = SliderTiming(object.time, path.length, slider.spans, source.slider_multiplier,
				source.slider_tick_rate, source.timing_points, source.format_version)
			add(object.time, object.x, "fruit", object.sounds)
			local previous = object.time
			for _, checkpoint in ipairs(timing.checkpoints) do
				local gap = checkpoint.time - previous
				local subdivisions = 1
				while gap / subdivisions > 0.1 do subdivisions = subdivisions * 2 end
				assert(subdivisions < 100000, "Catch prototype: stream budget exceeded.")
				for j = 1, subdivisions - 1 do
					local time = previous + gap * j / subdivisions
					local x = path:position(timing:progress(time))
					add(time, x, "tiny", {})
				end
				local x = path:position(checkpoint.progress)
				add(checkpoint.time, x, checkpoint.kind == "tick" and "droplet" or "fruit", object.sounds)
				previous = checkpoint.time
			end
		else
			local duration = assert(object.end_time) - object.time
			local step = duration
			while step > 0.1 do step = step / 2 end
			assert(duration / step < 100000, "Catch prototype: banana budget exceeded.")
			for j = 0, math.floor(duration / step) do
				seed = seed * 16807 % 2147483647
				add(object.time + j * step, seed / 2147483647 * 512, "banana", {})
			end
		end
	end
	table.sort(self.objects, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.order < b.order
	end)
	for _, object in ipairs(self.objects) do object.order = nil end
end

return CatchChart
