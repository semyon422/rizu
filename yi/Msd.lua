local class = require("class")

local math_util = require("math_util")

---@alias yi.Msd.Pattern "overall" | "stream" | "jumpstream" | "handstream" | "stamina" | "jackspeed" | "chordjack" | "technical"
---@alias yi.Msd.KV { name: yi.Msd.Pattern, difficulty: number }

---@class yi.Msd
---@operator call: yi.Msd
---@field patterns yi.Msd.KV[]
local Msd = class()

local MIN_RATE = 7
local MAX_RATE = 20
local PATTERN_ORDER = {
	"overall",
	"stream",
	"jumpstream",
	"handstream",
	"stamina",
	"jackspeed",
	"chordjack",
	"technical",
}

---@param pattern_map table<yi.Msd.Pattern, number>?
---@param rate_multipliers number[]?
function Msd:new(pattern_map, rate_multipliers)
	self.pattern_map = pattern_map
	self.patterns = {}
	self.rate_multipliers = rate_multipliers

	if not pattern_map or not rate_multipliers then
		return
	end

	self.valid = true

	for pattern, value in pairs(pattern_map) do
		table.insert(self.patterns, {name = pattern, difficulty = value})
	end

	table.sort(self.patterns, function(a, b)
		return a.difficulty > b.difficulty
	end)
end

---@param time_rate number
---@return number
function Msd:getApproximateMultiplier(time_rate)
	local floor = math_util.clamp(math.floor(time_rate * 10), MIN_RATE, MAX_RATE) - MIN_RATE + 1
	local ceil = math_util.clamp(math.ceil(time_rate * 10), MIN_RATE, MAX_RATE) - MIN_RATE + 1

	if floor == ceil then
		return self.rate_multipliers[floor]
	end

	local lower = self.rate_multipliers[floor]
	local upper = self.rate_multipliers[ceil]

	return (lower + upper) / 2
end

---@param time_rate number
---@return number
function Msd:getOverall(time_rate)
	local multiplier = self:getApproximateMultiplier(time_rate)
	return self.pattern_map.overall * multiplier
end

---@param name string
---@param inputmode string
---@return string
local function getPatternName(name, inputmode)
	if name == "jumpstream" and inputmode ~= "4key" then
		name = "chordstream"
	elseif name == "handstream" and inputmode ~= "4key" then
		name = "bracket"
	end
	return name
end

---@param time_rate number
---@param inputmode string
---@return yi.Msd.KV
function Msd:getPatterns(time_rate, inputmode)
	local multiplier = self:getApproximateMultiplier(time_rate)
	local t = {}
	for _, v in ipairs(self.patterns) do
		if v.name ~= "overall" then
			local name = getPatternName(v.name, inputmode)
			table.insert(t, {name = name, difficulty = v.difficulty * multiplier})
		end
	end
	return t
end

---@param time_rate number
---@param inputmode string
---@return yi.Msd.KV
function Msd:getOrderedByPattern(time_rate, inputmode)
	local multiplier = self:getApproximateMultiplier(time_rate)
	local t = {}
	for _, v in ipairs(PATTERN_ORDER) do
		local name = getPatternName(v, inputmode)
		table.insert(t, {name = name, difficulty = self.pattern_map[v] * multiplier})
	end
	return t
end

---@param pattern  string
---@return string
function Msd.simplifyName(pattern)
	if pattern == "stream" then
		return "STR"
	elseif pattern == "jumpstream" then
		return "JS"
	elseif pattern == "chordstream" then
		return "CSTR"
	elseif pattern == "bracket" then
		return "BRKT"
	elseif pattern == "handstream" then
		return "HS"
	elseif pattern == "chordjack" then
		return "CJ"
	elseif pattern == "stamina" then
		return "STMN"
	elseif pattern == "jackspeed" then
		return "JACK"
	elseif pattern == "technical" then
		return "TECH"
	end
	return "ALL"
end

return Msd
