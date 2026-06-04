local UIEvent = require("gui.input.UIEvent")

---@class gui.KeyboardEvent : gui.UIEvent
---@operator call: gui.KeyboardEvent
---@field key love.KeyConstant
---@field is_repeated boolean
local KeyboardEvent = UIEvent + {}

return KeyboardEvent
