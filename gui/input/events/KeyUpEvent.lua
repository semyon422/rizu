local KeyboardEvent = require("gui.input.events.KeyboardEvent")

---@class gui.KeyUpEvent : gui.KeyboardEvent
---@operator call: gui.KeyboardEvent
local KeyUpEvent = KeyboardEvent + {}

function KeyUpEvent:trigger()
	return self:getDispatchTarget():onKeyUp(self)
end

return KeyUpEvent
