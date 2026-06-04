local UIEvent = require("gui.input.UIEvent")

---@class gui.HoverEvent : gui.UIEvent
---@operator call: gui.HoverEvent
local HoverEvent = UIEvent + {}

function HoverEvent:trigger()
	return self:getDispatchTarget():onHover(self)
end

return HoverEvent
