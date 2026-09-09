local class = require("class")
local bit = require("bit")

---@class chart.osu.AimSlider
---@field curve_type string
---@field controls chart.osu.PathPoint[] Includes the head.
---@field length number
---@field spans integer

---@class chart.osu.AimObject
---@field time number
---@field x number
---@field y number
---@field kind "circle"|"slider"|"spinner"|"unsupported"
---@field end_time number? Spinner end time in seconds.
---@field slider chart.osu.AimSlider?
---@field sounds {[1]: string, [2]: number}[]

---@class chart.osu.AimChart
---@operator call: chart.osu.AimChart
---@field circle_size number
---@field approach_rate number
---@field overall_difficulty number
---@field objects chart.osu.AimObject[]
---@field timing_points chart.osu.SliderControlPoint[]
---@field format_version integer
---@field slider_multiplier number
---@field slider_tick_rate number
local AimChart = class()

---@param osu chart.osu.Osu
function AimChart:new(osu)
	local difficulty = osu.rawOsu.Difficulty
	self.circle_size = assert(tonumber(difficulty.CircleSize))
	self.overall_difficulty = assert(tonumber(difficulty.OverallDifficulty))
	self.approach_rate = tonumber(rawget(difficulty, "ApproachRate")) or self.overall_difficulty
	self.format_version = osu.rawOsu.format_version
	self.slider_multiplier = assert(tonumber(difficulty.SliderMultiplier))
	self.slider_tick_rate = assert(tonumber(difficulty.SliderTickRate))
	self.timing_points = {}
	for i, point in ipairs(osu.rawOsu.TimingPoints) do
		self.timing_points[i] = {offset = point.offset, beatLength = point.beatLength}
	end
	self.objects = {}
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
		self.objects[i] = {time = object.time / 1000, x = object.x, y = object.y, kind = kind, sounds = sounds}
		if kind == "spinner" then
			self.objects[i].end_time = object.endTime and object.endTime / 1000
		elseif kind == "slider" then
			local controls = {{object.x, object.y}}
			for _, point in ipairs(assert(object.points)) do
				controls[#controls + 1] = {point[1], point[2]}
			end
			self.objects[i].slider = {
				curve_type = assert(object.curveType), controls = controls,
				length = assert(object.length), spans = assert(object.repeatCount),
			}
		end
	end
end

---@param chart chart.osu.AimChart
---@return boolean
---@return string?
function AimChart.isSupported(chart)
	if #chart.objects == 0 then
		return false, "Aim prototype: this chart has no objects."
	end
	for _, value in ipairs({chart.circle_size, chart.approach_rate, chart.overall_difficulty}) do
		if type(value) ~= "number" or value ~= value or value < 0 or value > 10 then
			return false, "Aim prototype: unsupported difficulty settings."
		end
	end
	local previous_time = -math.huge
	for _, object in ipairs(chart.objects) do
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

return AimChart
