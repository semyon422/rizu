local table_util = require("table_util")
local Objects = require("chart.format.osu.Objects")
local bit = require("bit")

---@class chart.osu.AimSlider
---@field curve_type string
---@field controls chart.osu.PathPoint[] Includes the head.
---@field length number
---@field sample_addition chart.osu.Addition?
---@field sound_type number
---@field edge_sounds number[]
---@field edge_sets number[]
---@field edge_add_sets number[]
---@field checkpoint_sounds {[1]: string, [2]: number}[][]?
---@field spans integer

---@class chart.osu.AimObject
---@field time number
---@field x number
---@field y number
---@field kind "circle"|"slider"|"spinner"|"unsupported"
---@field stack_height integer? Runtime-only stacking height.
---@field end_time number? Spinner end time in seconds.
---@field slider chart.osu.AimSlider?
---@field sounds {[1]: string, [2]: number}[]

---@class chart.osu.AimData
---@field sample_set integer
---@field stack_leniency number
---@field circle_size number
---@field approach_rate number
---@field overall_difficulty number
---@field timing_points chart.osu.ControlPoint[]
---@field format_version integer
---@field slider_multiplier number
---@field slider_tick_rate number
local AimDecoder = {}

---@param osu chart.osu.Osu
---@param chart chart.Chart
---@param layer chart.AbsoluteLayer
---@param visual chart.Visual
function AimDecoder.decode(osu, chart, layer, visual)
	local data = chart.data
	local sample_sets = {None = 1, Normal = 1, Soft = 2, Drum = 3, ["0"] = 1, ["1"] = 1, ["2"] = 2, ["3"] = 3}
	data.sample_set = assert(sample_sets[osu.rawOsu.General.SampleSet], "Aim prototype: invalid general sample set.")
	local difficulty = osu.rawOsu.Difficulty
	local leniency = rawget(osu.rawOsu.General, "StackLeniency")
	data.stack_leniency = leniency == nil and 0.7 or assert(tonumber(leniency))
	data.circle_size = assert(tonumber(difficulty.CircleSize))
	data.overall_difficulty = assert(tonumber(difficulty.OverallDifficulty))
	data.approach_rate = tonumber(rawget(difficulty, "ApproachRate")) or data.overall_difficulty
	data.format_version = osu.rawOsu.format_version
	data.slider_multiplier = assert(tonumber(difficulty.SliderMultiplier))
	data.slider_tick_rate = assert(tonumber(difficulty.SliderTickRate))
	data.timing_points = {}
	for i, point in ipairs(osu.rawOsu.TimingPoints) do
		data.timing_points[i] = table_util.copy(point)
	end
	for i, object in ipairs(osu.rawOsu.HitObjects) do
		local kind = "unsupported"
		if bit.band(object.type, 2) ~= 0 then
			kind = "slider"
		elseif bit.band(object.type, 8) ~= 0 then
			kind = "spinner"
		elseif bit.band(object.type, 1) ~= 0 then
			kind = "circle"
		end
		---@type {[1]: string, [2]: number}[]
		local sounds = {}
		local proto = osu.protoNotes[i]
		if proto then
			for _, sound in ipairs(proto.sounds) do
				sounds[#sounds + 1] = {sound.name, sound.volume / 100}
			end
		end
		local result = {time = object.time / 1000, x = object.x, y = object.y, kind = kind, sounds = sounds}
		if kind == "spinner" then
			result.end_time = object.endTime and object.endTime / 1000
		elseif kind == "slider" then
			local controls = {{object.x, object.y}}
			for _, point in ipairs(assert(object.points)) do
				controls[#controls + 1] = {point[1], point[2]}
			end
			result.slider = {
				curve_type = assert(object.curveType), controls = controls,
				length = assert(object.length), spans = assert(object.repeatCount),
				sample_addition = {
					sampleSet = object.addition.sampleSet, addSampleSet = object.addition.addSampleSet,
					customSample = object.addition.customSample, volume = object.addition.volume,
					sampleFile = object.addition.sampleFile,
				},
				sound_type = object.soundType,
				edge_sounds = table_util.copy(object.sounds or {}),
				edge_sets = table_util.copy(object.ss or {}),
				edge_add_sets = table_util.copy(object.ssa or {}),
			}
		end
		Objects.insert(chart, layer, visual, "osu", result)
	end
end

---@param chart chart.Chart
---@return boolean
---@return string?
function AimDecoder.isSupported(chart)
	local objects = Objects.get(chart, "osu")
	if #objects == 0 then
		return false, "Aim prototype: this chart has no objects."
	end
	for _, value in ipairs({chart.data.circle_size, chart.data.approach_rate, chart.data.overall_difficulty}) do
		if type(value) ~= "number" or value ~= value or value < 0 or value > 10 then
			return false, "Aim prototype: unsupported difficulty settings."
		end
	end
	if chart.data.stack_leniency ~= nil and (chart.data.stack_leniency ~= chart.data.stack_leniency or chart.data.stack_leniency < 0 or chart.data.stack_leniency > 1) then
		return false, "Aim prototype: invalid stack leniency."
	end
	local previous_time = -math.huge
	for _, object in ipairs(objects) do
		if object.kind ~= "circle" and object.kind ~= "slider" and object.kind ~= "spinner" then
			return false, "Aim prototype: unsupported object type " .. object.kind .. "."
		end
		if object.kind == "spinner" and (not object.end_time or object.end_time ~= object.end_time or object.end_time == math.huge or object.end_time <= object.time) then
			return false, "Aim prototype: invalid spinner duration."
		end
		if object.time ~= object.time or math.abs(object.time) == math.huge or object.time < previous_time then
			return false, "Aim prototype: invalid or unordered object times."
		end
		previous_time = object.time
	end
	return true
end

return AimDecoder
