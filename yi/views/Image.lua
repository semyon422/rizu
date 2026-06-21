local View = require("gui.View")

---@class yi.ImageParams
---@field atlas love.Image
---@field quad love.Quad
---@field color gui.Color?
---@field size_scale number
---@field fit_box boolean

---@class yi.Image : gui.View
---@operator call: yi.Image
local Image = View + {}

---@param params yi.ImageParams
function Image:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Image atlas is required")
	self.quad = assert(params.quad, "Image quad is required")
	self.color = params.color or {1, 1, 1, 1}

	local _, _, w, h = self.quad:getViewport()
	self.size_scale_x = params.size_scale or 1
	self.size_scale_y = self.size_scale_x
	self.image_width, self.image_height = w * self.size_scale_x, h * self.size_scale_y
	self.fit_box = params.fit_box

	if not self.fit_box then
		self.width, self.height = self.image_width, self.image_height
	end
end

function Image:load()
	if self.fit_box then
		local _, _, iw, ih = self.quad:getViewport()
		local bw, bh = self.box:getDimensions()
		self.size_scale_x = bw / iw
		self.size_scale_y = bh / ih
		self.width = bw
		self.height = bh
	end
end

function Image:draw()
	love.graphics.setColor(self.color)
	love.graphics.scale(self.size_scale_x, self.size_scale_y)
	love.graphics.draw(self.atlas, self.quad)
end

return Image
