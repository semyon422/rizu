local class = require("class")

local LoveSleepFunction = require("rizu.loop.sleep.LoveSleepFunction")
local WinapiSleepFunction = require("rizu.loop.sleep.WinapiSleepFunction")
local NanosleepFunction = require("rizu.loop.sleep.NanosleepFunction")

---@alias rizu.SleepFunctionType "love"|"winapi"|"nanosleep"

---@class rizu.SleepFunctionFactory
---@operator call: rizu.SleepFunctionFactory
local SleepFunctionFactory = class()

function SleepFunctionFactory:new()
	---@type {[rizu.SleepFunctionType]: table}
	self.types = {
		love = LoveSleepFunction,
		winapi = WinapiSleepFunction,
		nanosleep = NanosleepFunction,
	}
	---@type {[rizu.SleepFunctionType]: rizu.ISleepFunction}
	self.instances = {}
end

---@param _type rizu.SleepFunctionType
---@return rizu.ISleepFunction
function SleepFunctionFactory:get(_type)
	if not self.instances[_type] then
		local T = self.types[_type] or LoveSleepFunction
		self.instances[_type] = T()
	end
	return self.instances[_type]
end

---@return rizu.SleepFunctionType[]
function SleepFunctionFactory:getAvailableTypes()
	local os_name = love.system.getOS()
	local available = {}
	for name, T in pairs(self.types) do
		if T:isAvailable(os_name) then
			table.insert(available, name)
		end
	end
	table.sort(available)
	return available
end

return SleepFunctionFactory
