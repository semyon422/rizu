local Setting = require("rizu.config.Setting")

---@class rizu.config.kinds.Range: rizu.config.Setting
---@operator call: rizu.config.kinds.Range
---@field min_value number
---@field max_value number
---@field step number
---@field format? string | fun(v: number): string
local Range = Setting + {}

---@param default_value number
---@param min_value number
---@param max_value number
---@param step? number
---@param format? string | fun(v: number): string
function Range:new(default_value, min_value, max_value, step, format)
	Setting.new(self, "range", default_value)
	self.min_value = min_value
	self.max_value = max_value
	self.step = step or 1
	self.format = format
end

return Range
