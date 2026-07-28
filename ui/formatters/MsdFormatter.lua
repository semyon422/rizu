local class = require("class")
local math_util = require("math_util")

---@alias ui.formatters.MsdFormatter.Pattern 
---| "overall" 
---| "stream" 
---| "jumpstream" 
---| "handstream" 
---| "stamina" 
---| "jackspeed" 
---| "chordjack" 
---| "technical"

---@alias ui.formatters.MsdFormatter.KV { name: ui.formatters.MsdFormatter.Pattern, difficulty: number }

---@class ui.formatters.MsdFormatter
---@operator call: ui.formatters.MsdFormatter
---@field patterns ui.formatters.MsdFormatter.KV[]
local MsdFormatter = class()

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

---@param pattern_map {[ui.formatters.MsdFormatter.Pattern]: number}
---@param rate_multipliers number[]
function MsdFormatter:new(pattern_map, rate_multipliers)
	self.pattern_map = pattern_map
	self.patterns = {}
	self.rate_multipliers = rate_multipliers

	for pattern, value in pairs(pattern_map) do
		table.insert(self.patterns, {name = pattern, difficulty = value})
	end

	table.sort(self.patterns, function(a, b)
		return a.difficulty > b.difficulty
	end)
end

---@param time_rate number
---@return number
function MsdFormatter:getApproximateMultiplier(time_rate)
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
function MsdFormatter:getOverall(time_rate)
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
---@return ui.formatters.MsdFormatter.KV
function MsdFormatter:getPatterns(time_rate, inputmode)
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
---@return ui.formatters.MsdFormatter.KV
function MsdFormatter:getOrderedByPattern(time_rate, inputmode)
	local multiplier = self:getApproximateMultiplier(time_rate)
	local t = {}
	for _, v in ipairs(PATTERN_ORDER) do
		local name = getPatternName(v, inputmode)
		table.insert(t, {name = name, difficulty = self.pattern_map[v] * multiplier})
	end
	return t
end

---@param time_rate number
---@return ui.formatters.MsdFormatter.Pattern
---@return ui.formatters.MsdFormatter.Pattern?
function MsdFormatter:getTopPatterns(time_rate)
	local multiplier = self:getApproximateMultiplier(time_rate)
	---@type ui.formatters.MsdFormatter.KV
	local top

	for _, pattern in ipairs(self.patterns) do
		if pattern.name ~= "overall" then
			top = pattern
			break
		end
	end

	local top_difficulty = top.difficulty * multiplier
	for _, pattern in ipairs(self.patterns) do
		local difficulty = pattern.difficulty * multiplier
		if pattern.name ~= "overall" and pattern.name ~= top.name and difficulty > top_difficulty * 0.93 then
			return top.name, pattern.name
		end
	end

	return top.name
end

---@param pattern string
---@return string
function MsdFormatter.simplifyName(pattern)
	if pattern == "stream" then
		return "STR"
	elseif pattern == "jumpstream" then
		return "JS"
	elseif pattern == "chordstream" then
		return "CSTR"
	elseif pattern == "bracket" then
		return "BRACKET"
	elseif pattern == "handstream" then
		return "HS"
	elseif pattern == "chordjack" then
		return "CJ"
	elseif pattern == "stamina" then
		return "STAMINA"
	elseif pattern == "jackspeed" then
		return "JACK"
	elseif pattern == "technical" then
		return "TECH"
	end
	return "ALL"
end

return MsdFormatter
