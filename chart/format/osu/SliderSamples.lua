local Sounds = require("chart.format.osu.Sounds")
local Addition = require("chart.format.osu.sections.Addition")
local bit = require("bit")

local SliderSamples = {}

---@param chart chart.osu.AimChart
---@param time number Seconds.
---@return chart.osu.ControlPoint
local function pointAt(chart, time)
	local selected = {offset = 0, beatLength = 500, sampleSet = chart.sample_set, customSamples = 0, volume = 100}
	local low, high = 1, #chart.timing_points
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if chart.timing_points[mid].offset <= time * 1000 then
			selected = chart.timing_points[mid]
			low = mid + 1
		else high = mid - 1 end
	end
	return {offset = selected.offset, beatLength = selected.beatLength, sampleSet = selected.sampleSet,
		customSamples = selected.customSamples, volume = selected.volume}
end

---@param chart chart.osu.AimChart
---@param slider chart.osu.AimSlider
---@param edge integer
---@param time number
---@return chart.osu.Sound[]
function SliderSamples.edge(chart, slider, edge, time)
	local source = assert(slider.sample_addition)
	local addition = Addition()
	addition.sampleSet = slider.edge_sets[edge] or 0
	if addition.sampleSet == 0 then addition.sampleSet = source.sampleSet end
	addition.addSampleSet = slider.edge_add_sets[edge] or 0
	if addition.addSampleSet == 0 then addition.addSampleSet = source.addSampleSet end
	addition.customSample, addition.volume = source.customSample, source.volume
	-- Custom filenames belong to the head, not every repeat/tail.
	addition.sampleFile = edge == 1 and source.sampleFile or ""
	local point = pointAt(chart, time)
	if addition.sampleSet == 0 and point.sampleSet == 0 then addition.sampleSet = chart.sample_set end
	local index = addition.customSample
	if index == 0 then index = point.customSamples end
	-- osu!'s first sample bank uses the unsuffixed filename.
	addition.customSample = index > 1 and index or 0
	point.customSamples = 0
	local volume = addition.volume > 0 and addition.volume or point.volume
	local mask = slider.edge_sounds[edge] or slider.sound_type
	local samples = Sounds:decode(bit.bor(mask, 1), addition, point)
	for _, sample in ipairs(samples) do
		sample.volume = sample.volume * volume / math.max(volume, 8)
	end
	return samples
end

---@param chart chart.osu.AimChart
---@param slider chart.osu.AimSlider
---@param time number
---@return chart.osu.Sound[]
function SliderSamples.tick(chart, slider, time)
	local source = assert(slider.sample_addition)
	local point = pointAt(chart, time)
	local set = source.sampleSet
	if set == 0 then set = point.sampleSet end
	if set == 0 then set = chart.sample_set end
	local names = {[1] = "normal", [2] = "soft", [3] = "drum"}
	local name = assert(names[set], "Aim prototype: invalid slider sample set.") .. "-slidertick"
	local index = source.customSample
	if index == 0 then index = point.customSamples end
	local volume = source.volume
	if volume == 0 then volume = point.volume end
	local filename = index > 1 and (name .. index) or name
	return {{name = filename, fallback_name = name, volume = volume}}
end

---@param samples chart.osu.Sound[]
---@param resources chart.Resources
---@param tick boolean?
---@return {[1]: string, [2]: number}[]
local function register(samples, resources, tick)
	---@type {[1]: string, [2]: number}[]
	local result = {}
	for _, sample in ipairs(samples) do
		if tick then resources:add("sound", sample.name, sample.fallback_name, "aim-slidertick")
		else resources:add("sound", sample.name, sample.fallback_name) end
		result[#result + 1] = {sample.name, sample.volume / 100}
	end
	return result
end

---@param chart chart.osu.AimChart
---@param sliders {[integer]: rizu.aim.Slider}
---@param resources chart.Resources
function SliderSamples.prepare(chart, sliders, resources)
	for i, runtime in pairs(sliders) do
		local object = chart.objects[i]
		local source = assert(object.slider)
		-- Hand-authored headless fixtures may intentionally omit sound metadata.
		if source.sample_addition then
			object.sounds = register(SliderSamples.edge(chart, source, 1, object.time), resources)
			source.checkpoint_sounds = {}
			local edge = 2
			for j, checkpoint in ipairs(runtime.timing.checkpoints) do
				---@type chart.osu.Sound[]
				local samples
				if checkpoint.kind == "tick" then
					samples = SliderSamples.tick(chart, source, checkpoint.time)
				else
					samples = SliderSamples.edge(chart, source, edge, checkpoint.time)
					edge = edge + 1
				end
				source.checkpoint_sounds[j] = register(samples, resources, checkpoint.kind == "tick")
			end
		end
	end
end

return SliderSamples
