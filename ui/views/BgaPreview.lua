local View = require("gui.View")
local BgaRenderer = require("ui.views.BgaRenderer")

---@class ui.views.BgaPreview : gui.View
---@operator call: ui.views.BgaPreview
---@field media rizu.api.Media
---@field renderer ui.views.BgaRenderer
local BgaPreview = View + {}

---@param media rizu.api.Media
function BgaPreview:new(media)
	View.new(self)
	self.media = media
	self.renderer = BgaRenderer()
end

function BgaPreview:draw()
	local player, time = self.media:getBackgroundAnimation()
	self.renderer:draw(player, time, self.width, self.height)
end

return BgaPreview
