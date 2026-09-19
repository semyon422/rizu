local View = require("gui.View")
local BgaRenderer = require("ui.views.BgaRenderer")

---@class ui.views.BgaPreview : gui.View
---@operator call: ui.views.BgaPreview
---@field preview_model rizu.preview.PreviewModel
---@field renderer ui.views.BgaRenderer
local BgaPreview = View + {}

---@param preview_model rizu.preview.PreviewModel
function BgaPreview:new(preview_model)
	View.new(self)
	self.preview_model = preview_model
	self.renderer = BgaRenderer()
end

function BgaPreview:draw()
	self.renderer:draw(
		self.preview_model.bgaPreviewPlayer,
		self.preview_model:getTime(),
		self.width,
		self.height
	)
end

return BgaPreview
