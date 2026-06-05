local View = require("gui.View")

---@class yi.RectangleParams
---@field atlas love.Image
---@field quad love.Quad
---@field color number[]?
---@field fit_box boolean
---@field blend_mode string

---@class yi.Rectangle : gui.View
---@overload fun(params: yi.RectangleParams): yi.Rectangle
---@field atlas love.Image
---@field quad love.Quad
---@field color number[]
---@field blend_mode string
local Rectangle = View + {}

---@param params yi.RectangleParams
function Rectangle:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Rectangle atlas is required")
	self.quad = assert(params.quad, "Rectangle quad is required")
	self.color = params.color or {1, 1, 1, 1}
	self.fit_box = params.fit_box
	self.blend_mode = params.blend_mode
end

function Rectangle:draw()
	love.graphics.setColor(self.color)
	love.graphics.setBlendMode(self.blend_mode)
	if self.fit_box then
		love.graphics.draw(self.atlas, self.quad, 0, 0, 0, self.box.width, self.box.height)
	else
		love.graphics.draw(self.atlas, self.quad, 0, 0, 0, self.width, self.height)
	end
end

return Rectangle
