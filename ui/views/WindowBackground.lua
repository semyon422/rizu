local NineSlice = require("gui.NineSlice")
local Resources = require("ui.Resources")

---@class ui.views.WindowBackground : gui.NineSlice
---@operator call: ui.views.WindowBackground
local WindowBackground = NineSlice + {}

function WindowBackground:new()
	NineSlice.new(self, Resources.nine_slices.window_background)
	self:setLayoutIgnore(true)
end

return WindowBackground
