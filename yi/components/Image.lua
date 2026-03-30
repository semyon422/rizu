local View = require("ui.View")

---@class yi.ImageParams
---@field atlas love.Image
---@field quad love.Quad

---@class yi.Image : ui.View
---@operator call: yi.Image
local Image = View + {}

---@param params yi.ImageParams
function Image:new(params)
	View.new(self)
	self.atlas = params.atlas
	self.quad = params.quad
	self.color = params.color

	local _, _, w, h = self.quad:getViewport()
	self.width, self.height = w, h
end

function Image:draw()
	love.graphics.setColor(self.color)
	love.graphics.draw(self.atlas, self.quad)
end

return Image
