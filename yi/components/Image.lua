local View = require("ui.View")

---@class yi.ImageParams
---@field atlas love.Image
---@field quad love.Quad
---@field color ui.Color?
---@field size_scale number

---@class yi.Image : ui.View
---@operator call: yi.Image
local Image = View + {}

---@param params yi.ImageParams
function Image:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Image atlas is required")
	self.quad = assert(params.quad, "Image quad is required")
	self.color = params.color or {1, 1, 1, 1}

	local _, _, w, h = self.quad:getViewport()
	self.size_scale = params.size_scale or 1
	self.width = w * self.size_scale
	self.height = h * self.size_scale
end

function Image:draw()
	love.graphics.setColor(self.color)
	love.graphics.scale(self.size_scale)
	love.graphics.draw(self.atlas, self.quad)
end

return Image
