local HudElement = require("rizu.skin.hud.HudElement")

---A filled rectangle.
---@class rizu.skin.hud.elements.Box : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.Box
local Box = HudElement + {}

Box.label = "Box"
Box.fields = {
	{key = "width", label = "Width", min = 0, max = 1280, step = 1, default = 100},
	{key = "height", label = "Height", min = 0, max = 960, step = 1, default = 20},
	{key = "color", label = "Color", type = "color", default = {0, 0, 0, 0.5}},
}

function Box:applyValues()
	HudElement.applyValues(self)
	self.width, self.height = self.values.width --[[@as number]], self.values.height --[[@as number]]
end

function Box:draw()
	HudElement.setColor(self.values.color --[[@as number[] ]])
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
end

return Box
