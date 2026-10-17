local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.MouseDownEvent : gui.MouseButtonEvent
---@operator call: gui.MouseDownEvent
local MouseDownEvent = MouseButtonEvent + {}

function MouseDownEvent:trigger()
	return self:getDispatchTarget():onMouseDown(self)
end

return MouseDownEvent
