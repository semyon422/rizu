local UIEvent = require("gui.input.UIEvent")

---@class gui.KeyboardEvent : gui.UIEvent
---@operator call: gui.KeyboardEvent
---@field key love.KeyConstant?
---@field text string?
---@field is_repeated boolean?
---@field device "keyboard"?
---@field device_id integer?
local KeyboardEvent = UIEvent + {}

return KeyboardEvent
