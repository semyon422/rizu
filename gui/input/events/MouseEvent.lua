local UIEvent = require("gui.input.UIEvent")

---@class gui.MouseEvent : gui.UIEvent
---@operator call: gui.MouseEvent
---@field button number
---@field x number
---@field y number
---@field time number Event time in seconds
---@field press_x number? Pointer X at the start of a drag
---@field press_y number? Pointer Y at the start of a drag
---@field press_time number? Pointer press time in seconds
local MouseEvent = UIEvent + {}

return MouseEvent
