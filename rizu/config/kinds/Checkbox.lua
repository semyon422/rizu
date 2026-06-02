local Setting = require("rizu.config.Setting")

---@class rizu.config.kinds.Checkbox: rizu.config.Setting
---@operator call: rizu.config.kinds.Checkbox
local Checkbox = Setting + {}

---@param default_value boolean
function Checkbox:new(default_value)
	Setting.new(self, "checkbox", not not default_value)
end

return Checkbox
