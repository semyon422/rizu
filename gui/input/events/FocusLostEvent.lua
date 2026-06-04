local UIEvent = require("gui.input.UIEvent")

---@class gui.FocusLostEvent : gui.UIEvent
---@operator call: gui.FocusLostEvent
---@field next_focused gui.View?
local FocusLostEvent = UIEvent + {}

function FocusLostEvent:trigger()
	return self:getDispatchTarget():onFocusLost(self)
end

return FocusLostEvent
