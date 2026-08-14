local math_util = require("math_util")

---@alias rizu.gameplay.ScrollSpeed.Type "default"|"osu"

---@class rizu.gameplay.ScrollSpeed
local ScrollSpeed = {}

ScrollSpeed.types = {"default", "osu"}

ScrollSpeed.ranges = {
	default = {0.05, 3, 0.01},
	osu = {1, 40, 1},
}

ScrollSpeed.formats = {
	default = "%0.2f",
	osu = "%d",
}

ScrollSpeed.osu_factor = 7 / 96
ScrollSpeed.canonical_min = ScrollSpeed.ranges.default[1]
ScrollSpeed.canonical_max = ScrollSpeed.ranges.default[2]

---@param value number
---@param range number[]
---@return number
local function clamp(value, range)
	return math_util.clamp(value, range[1], range[2])
end

---@param speed_type rizu.gameplay.ScrollSpeed.Type
---@param canonical_speed number
---@return number display_speed
function ScrollSpeed.toDisplay(speed_type, canonical_speed)
	if speed_type == "osu" then
		return clamp(math_util.round(canonical_speed / ScrollSpeed.osu_factor), ScrollSpeed.ranges.osu)
	end
	return clamp(canonical_speed, ScrollSpeed.ranges.default)
end

---@param speed_type rizu.gameplay.ScrollSpeed.Type
---@param display_speed number
---@return number canonical_speed
function ScrollSpeed.toCanonical(speed_type, display_speed)
	display_speed = clamp(display_speed, assert(ScrollSpeed.ranges[speed_type]))
	if speed_type == "osu" then
		display_speed = display_speed * ScrollSpeed.osu_factor
	end
	return clamp(display_speed, ScrollSpeed.ranges.default)
end

---@param speed_type rizu.gameplay.ScrollSpeed.Type
---@param canonical_speed number
---@param delta number
---@return number canonical_speed
function ScrollSpeed.increase(speed_type, canonical_speed, delta)
	local display_speed = ScrollSpeed.toDisplay(speed_type, canonical_speed)
	if speed_type == "default" then
		delta = delta * 0.05
	end
	return ScrollSpeed.toCanonical(speed_type, display_speed + delta)
end

return ScrollSpeed
