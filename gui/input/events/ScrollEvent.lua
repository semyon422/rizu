local MouseEvent = require("gui.input.events.MouseEvent")

---@class gui.ScrollEvent : gui.MouseEvent
---@operator call: gui.ScrollEvent
---@field direction_x number
---@field direction_y number
local ScrollEvent = MouseEvent + {}

function ScrollEvent:trigger()
	return self:getDispatchTarget():onScroll(self)
end

return ScrollEvent
