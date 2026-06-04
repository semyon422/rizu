local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.MouseUpEvent : gui.MouseButtonEvent
---@operator call: gui.MouseUpEvent
local MouseUpEvent = MouseButtonEvent + {}

function MouseUpEvent:trigger()
	return self:getDispatchTarget():onMouseUp(self)
end

return MouseUpEvent
