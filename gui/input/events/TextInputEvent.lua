local KeyboardEvent = require("gui.input.events.KeyboardEvent")

---@class gui.TextInputEvent : gui.KeyboardEvent
---@operator call: gui.TextInputEvent
local TextInputEvent = KeyboardEvent + {}

function TextInputEvent:trigger()
	return self:getDispatchTarget():onTextInput(self)
end

return TextInputEvent
