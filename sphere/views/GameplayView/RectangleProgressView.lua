local transform = require("gfx_util").transform
local ProgressView = require("sphere.views.GameplayView.ProgressView")

---@class sphere.RectangleProgressView: sphere.ProgressView
---@operator call: sphere.RectangleProgressView
local RectangleProgressView = ProgressView + {}

function RectangleProgressView:draw()
	local tf = transform(self.transform)
	love.graphics.replaceTransform(tf)

	local x, y, w, h = self:getRectangle()

	love.graphics.setColor(self.color)
	love.graphics.rectangle("fill", x, y, w, h)
end

---@return number
---@return number
---@return number
---@return number
function RectangleProgressView:getRectangle()
	local dir = self.direction

	local x, y, w, h = 0, 0, 1, 1

	local a, b = self:getForm()
	if dir:find("left") then
		x, w = a, b
	elseif dir:find("up") then
		y, h = a, b
	end

	return x * self.w + self.x, y * self.h + self.y, w * self.w, h * self.h
end

return RectangleProgressView
