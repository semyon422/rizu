local View = require("gui.View")
local Resources = require("yi.Resources")

---@class yi.views.RectangleParams
---@field color number[]?
---@field fit_box boolean?

---@class yi.views.Rectangle : gui.View
---@overload fun(params: yi.views.RectangleParams): yi.views.Rectangle
---@field color number[]
local Rectangle = View + {}

---@param params yi.views.RectangleParams?
function Rectangle:new(params)
	View.new(self)
	self.color = {1, 1, 1, 1}
	self.fit_box = true

	if params then
		self.color = params.color or self.color
		self.fit_box = (params.fit_box == nil) and self.fit_box or params.fit_box
	end

	if self.fit_box then
		self.draw = self.drawFitBox
	else
		self.draw = self.drawNormal
	end
end

function Rectangle:drawFitBox()
	love.graphics.setColor(self.color)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.box.width, self.box.height)
end

function Rectangle:drawNormal()
	love.graphics.setColor(self.color)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
end

return Rectangle
