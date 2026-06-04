local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.DragStartEvent : gui.MouseButtonEvent
---@operator call: gui.DragStartEvent
local DragStartEvent = MouseButtonEvent + {}

function DragStartEvent:trigger()
	return self:getDispatchTarget():onDragStart(self)
end

return DragStartEvent
