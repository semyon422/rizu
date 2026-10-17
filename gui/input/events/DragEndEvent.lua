local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.DragEndEvent : gui.MouseButtonEvent
---@operator call: gui.DragEndEvent
local DragEndEvent = MouseButtonEvent + {}

function DragEndEvent:trigger()
	return self:getDispatchTarget():onDragEnd(self)
end

return DragEndEvent
