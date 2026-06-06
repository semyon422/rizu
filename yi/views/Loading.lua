local View = require("gui.View")
local Resources = require("yi.Resources")

---@class yi.views.Loading : gui.View
---@operator call: yi.views.Loading
local Loading = View + {}

local scale = 0.5

function Loading:new()
	View.new(self)
	self.atlas = Resources.atlas
	self.quad = Resources.quads.loading
	local _, _, w, h = self.quad:getViewport()
	self:setSize(w * scale, h * scale)
end

function Loading:draw()
	local _, _, w, h = self.quad:getViewport()

	love.graphics.draw(
		self.atlas,
		self.quad,
		w * scale / 2,
		h * scale / 2,
		love.timer.getTime(),
		scale,
		scale,
		w / 2,
		h / 2
	)
end

return Loading
