local View = require("ui.View")
local Colors = require("yi.Colors")

---@class yi.views.IconButton : ui.View
---@operator call: yi.views.IconButton
local IconButton = View + {}

---@param resources yi.Resources
---@param icon_quad love.Quad
function IconButton:new(resources, icon_quad)
	View.new(self)
	self.atlas = resources.atlas
	self.background_quad = resources.quads.background_icon_button
	self.icon_quad = icon_quad

	local _, _, bw, bh = self.background_quad:getViewport()
	local _, _, w, h = self.icon_quad:getViewport()
	self:setSize(bw, bh)

	self.icon_x = (bw - w) / 2
	self.icon_y = (bh - h) / 2
end

function IconButton:draw()
	love.graphics.setColor(Colors.icon_button_bg)
	love.graphics.draw(self.atlas, self.background_quad)
	love.graphics.setColor(Colors.text)
	love.graphics.draw(self.atlas, self.icon_quad, self.icon_x, self.icon_y)
end

return IconButton
