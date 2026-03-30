local View = require("ui.View")

---@class yi.RectangleParams
---@field atlas love.Image
---@field quad love.Quad
---@field color number[]?

---@class yi.Rectangle : ui.View
---@overload fun(params: yi.RectangleParams): yi.Rectangle
---@field atlas love.Image
---@field quad love.Quad
---@field color number[]?
local Rectangle = View + {}

---@param params yi.RectangleParams
function Rectangle:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Rectangle atlas is required")
	self.quad = assert(params.quad, "Rectangle quad is required")
	self.color = params.color or {1, 1, 1, 1}
end

function Rectangle:draw()
	love.graphics.setColor(self.color)
	love.graphics.draw(self.atlas, self.quad, 0, 0, 0, self.width, self.height)
end

return Rectangle
