local KeyboardEvent = require("gui.input.events.KeyboardEvent")

---@class gui.KeyDownEvent : gui.KeyboardEvent
---@operator call: gui.KeyboardEvent
local KeyDownEvent = KeyboardEvent + {}

function KeyDownEvent:trigger()
	return self:getDispatchTarget():onKeyDown(self)
end

return KeyDownEvent
