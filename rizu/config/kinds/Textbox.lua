local Setting = require("rizu.config.Setting")

---@class rizu.config.kinds.Textbox: rizu.config.Setting
---@operator call: rizu.config.kinds.Textbox
---@field is_secret boolean
---@field max_characters? number
local Textbox = Setting + {}

---@param default_value string
---@param is_secret? boolean
---@param max_characters? number
function Textbox:new(default_value, is_secret, max_characters)
	Setting.new(self, "textbox", default_value or "")
	self.is_secret = not not is_secret
	self.max_characters = max_characters
end

return Textbox
