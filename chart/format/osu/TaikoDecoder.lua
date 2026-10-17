local Objects = require("chart.format.osu.Objects")
local bit = require("bit")
local SliderTiming = require("chart.format.osu.SliderTiming")

---@class chart.osu.TaikoObject
---@field time number
---@field end_time number
---@field kind "note"|"roll"|"spinner"
---@field color "don"|"kat"
---@field big boolean
---@field target integer
---@field sounds {[1]: string, [2]: number}[]

local TaikoDecoder = {}

---@param osu chart.osu.Osu
---@param chart chart.Chart
---@param layer chart.AbsoluteLayer
---@param visual chart.Visual
function TaikoDecoder.decode(osu, chart, layer, visual)
	local raw = osu.rawOsu
	assert(tonumber(raw.General.Mode) == 1, "Taiko prototype: only native Mode=1 charts are supported.")
	chart.data.overall_difficulty = assert(tonumber(raw.Difficulty.OverallDifficulty))
	assert(chart.data.overall_difficulty >= 0 and chart.data.overall_difficulty <= 10, "Taiko prototype: invalid OD.")
	assert(#raw.HitObjects > 0 and #raw.HitObjects <= 100000, "Taiko prototype: invalid object count.")
	local previous = -math.huge
	local action_budget = 0
	for i, object in ipairs(raw.HitObjects) do
		local time = object.time / 1000
		assert(time == time and math.abs(time) < math.huge and time >= previous, "Taiko prototype: invalid or unordered times.")
		previous = time
		---@type chart.osu.TaikoObject
		local result = {
			time = time, end_time = time, kind = "note", target = 1,
			color = bit.band(object.soundType, 10) ~= 0 and "kat" or "don",
			big = bit.band(object.soundType, 4) ~= 0, sounds = {},
		}
		if bit.band(object.type, 2) ~= 0 then
			result.kind = "roll"
			local timing = SliderTiming(time, assert(object.length), assert(object.repeatCount),
				assert(tonumber(raw.Difficulty.SliderMultiplier)), assert(tonumber(raw.Difficulty.SliderTickRate)),
				raw.TimingPoints, raw.format_version)
			result.end_time = timing.end_time
		elseif bit.band(object.type, 8) ~= 0 then
			result.kind = "spinner"
			result.end_time = assert(object.endTime) / 1000
		else
			assert(bit.band(object.type, 1) ~= 0, "Taiko prototype: unsupported object type.")
		end
		if result.kind ~= "note" then
			local duration = result.end_time - time
			assert(duration > 0 and duration < math.huge, "Taiko prototype: invalid interval duration.")
			local density = result.kind == "roll" and 4 or 3 + 0.3 * chart.data.overall_difficulty
			result.target = math.max(1, math.ceil(duration * density))
			assert(result.target <= 10000, "Taiko prototype: interval hit budget exceeded.")
		end
		action_budget = action_budget + (result.kind == "note" and (result.big and 4 or 2) or result.target * 2)
		assert(action_budget <= 200000, "Taiko prototype: total action budget exceeded.")
		local proto = osu.protoNotes[i]
		if proto then
			for _, sound in ipairs(proto.sounds) do
				result.sounds[#result.sounds + 1] = {sound.name, sound.volume / 100}
			end
		end
		Objects.insert(chart, layer, visual, "taiko", result)
	end
end

return TaikoDecoder
