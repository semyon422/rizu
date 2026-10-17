local MouseButtonEvent = require("gui.input.events.MouseButtonEvent")

---@class gui.DragEvent : gui.MouseButtonEvent
---@operator call: gui.DragEvent
local DragEvent = MouseButtonEvent + {}

function DragEvent:trigger()
	return self:getDispatchTarget():onDrag(self)
end

return DragEvent
