local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.MouseClickEvent : gui.MouseButtonEvent
---@operator call: gui.MouseClickEvent
local MouseClickEvent = MouseButtonEvent + {}

function MouseClickEvent:trigger()
	return self:getDispatchTarget():onMouseClick(self)
end

return MouseClickEvent
