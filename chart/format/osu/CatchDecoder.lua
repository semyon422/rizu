local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local Objects = require("chart.format.osu.Objects")
local AimDecoder = require("chart.format.osu.AimDecoder")
local SliderPath = require("chart.format.osu.SliderPath")
local SliderTiming = require("chart.format.osu.SliderTiming")

---@class chart.osu.CatchObject
---@field order integer? Temporary stable sort key.
---@field time number
---@field x number
---@field kind "fruit"|"droplet"|"tiny"|"banana"
---@field sounds {[1]: string, [2]: number}[]

local CatchDecoder = {}

---@param osu chart.osu.Osu
---@param chart chart.Chart
---@param layer chart.AbsoluteLayer
---@param visual chart.Visual
function CatchDecoder.decode(osu, chart, layer, visual)
	-- Share the native osu source reader, not an Aim-to-Catch gameplay conversion.
	local builder = ChartBuilder()
	local source = builder.chart
	AimDecoder.decode(osu, source, builder:createAbsoluteLayer(), builder:getVisual("main"))
	local ok, err = AimDecoder.isSupported(source)
	assert(ok, err)
	chart.data.circle_size, chart.data.approach_rate = source.data.circle_size, source.data.approach_rate
	local objects = {}
	local seed = 1337
	local order = 0
	---@param time number
	---@param x number
	---@param kind "fruit"|"droplet"|"tiny"|"banana"
	---@param sounds {[1]: string, [2]: number}[]
	local function add(time, x, kind, sounds)
		assert(#objects < 100000, "Catch prototype: object budget exceeded.")
		order = order + 1
		objects[#objects + 1] = {time = time, x = math.max(0, math.min(512, x)), kind = kind, sounds = sounds, order = order}
	end
	for _, object in ipairs(Objects.get(source, "osu")) do
		if object.kind == "circle" then
			add(object.time, object.x, "fruit", object.sounds)
		elseif object.kind == "slider" then
			local slider = assert(object.slider)
			local path = SliderPath(slider.curve_type, slider.controls, slider.length)
			local timing = SliderTiming(object.time, path.length, slider.spans, source.data.slider_multiplier,
				source.data.slider_tick_rate, source.data.timing_points, source.data.format_version)
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
	table.sort(objects, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.order < b.order
	end)
	for _, object in ipairs(objects) do
		object.order = nil
		Objects.insert(chart, layer, visual, "catch", object)
	end
end

return CatchDecoder
