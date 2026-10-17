local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")
local table_util = require("table_util")

---@class sea.ChartmetaKey
---@operator call: sea.ChartmetaKey
---@field hash string
---@field index integer
local ChartmetaKey = class()

ChartmetaKey.struct = {
	hash = types.md5hash,
	index = valid.index,
}

assert(#table_util.keys(ChartmetaKey.struct) == 2)

local validate_chartmeta_key = valid.struct(ChartmetaKey.struct)

---@return true?
---@return string|valid.Errors?
function ChartmetaKey:validate()
	return validate_chartmeta_key(self)
end

---@param key sea.ChartmetaKey
---@return boolean
function ChartmetaKey:equalsChartmetaKey(key)
	return
		self.hash == key.hash and
		self.index == key.index
end

---@param chartmeta_key sea.ChartmetaKey
function ChartmetaKey:importChartmetaKey(chartmeta_key)
	for k in pairs(ChartmetaKey.struct) do
		self[k] = chartmeta_key[k] ---@diagnostic disable-line
	end
end

---@param chartmeta_key sea.ChartmetaKey
function ChartmetaKey:exportChartmetaKey(chartmeta_key)
	for k in pairs(ChartmetaKey.struct) do
		chartmeta_key[k] = self[k] ---@diagnostic disable-line
	end
end

return ChartmetaKey
