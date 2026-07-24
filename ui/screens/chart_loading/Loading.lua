local View = require("gui.View")
local Resources = require("ui.Resources")

---@class ui.screens.chart_loading.Loading : gui.View
---@operator call: ui.screens.chart_loading.Loading
local Loading = View + {}

local SCALE = 0.5

function Loading:new()
	View.new(self)
	self.quad = Resources.quads.loading
	local _, _, width, height = self.quad:getViewport()
	self:setSize(width * SCALE, height * SCALE)
end

function Loading:draw()
	local _, _, width, height = self.quad:getViewport()
	love.graphics.draw(
		Resources.atlas,
		self.quad,
		self.width / 2,
		self.height / 2,
		love.timer.getTime(),
		SCALE,
		SCALE,
		width / 2,
		height / 2
	)
end

return Loading
