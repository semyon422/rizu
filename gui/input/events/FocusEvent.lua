local UIEvent = require("gui.input.UIEvent")

---@class gui.FocusEvent : gui.UIEvent
---@operator call: gui.FocusEvent
---@field previously_focused gui.View?
local FocusEvent = UIEvent + {}

function FocusEvent:trigger()
	return self:getDispatchTarget():onFocus(self)
end

return FocusEvent
