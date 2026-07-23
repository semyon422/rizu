local View = require("gui.View")

---@class ui.views.Image : gui.View
---@operator call: ui.views.Image
local Image = View + {}

---@param texture love.Texture
---@param quad love.Quad
function Image:new(texture, quad)
	View.new(self)
	self.texture = texture
	self.quad = quad
	local _, _, w, h = self.quad:getViewport()
	self.offset_max = {w, h}
end

local lg = love.graphics

function Image:draw()
	lg.draw(self.texture, self.quad)
end

return Image
