local MouseEvent = require("gui.input.events.MouseEvent")

---@class gui.MouseButtonEvent : gui.MouseEvent
---@operator call: gui.MouseButtonEvent
---@field button number
local MouseButtonEvent = MouseEvent + {}

return MouseButtonEvent
