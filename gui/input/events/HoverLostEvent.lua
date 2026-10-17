local UIEvent = require("gui.input.UIEvent")

---@class gui.HoverLostEvent : gui.UIEvent
---@operator call: gui.HoverLostEvent
local HoverLostEvent = UIEvent + {}

function HoverLostEvent:trigger()
	return self:getDispatchTarget():onHoverLost(self)
end

return HoverLostEvent
