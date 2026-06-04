local UIEvent = require("gui.input.UIEvent")

---@class gui.MouseEvent : gui.UIEvent
---@operator call: gui.MouseEvent
---@field button number
---@field x number
---@field y number
local MouseEvent = UIEvent + {}

return MouseEvent
