local Setting = require("rizu.config.Setting")

---@class rizu.config.kinds.Choice: rizu.config.Setting
---@operator call: rizu.config.kinds.Choice
---@field options any[]
---@field format? string | fun(value: any): string
local Choice = Setting + {}

---@param default_value any
---@param options any[]
---@param format? string | fun(value: any): string
function Choice:new(default_value, options, format)
	Setting.new(self, "choice", default_value)
	self.options = options or {}
	self.format = format
end

return Choice
