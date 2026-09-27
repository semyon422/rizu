local ViewContainer = require("rizu.skin.ViewContainer")

---@class rizu.skin.Hud : rizu.skin.ViewContainer
---@operator call: rizu.skin.Hud
---@overload fun(config: rizu.skin.View.Config): rizu.skin.Hud
local Hud = ViewContainer + {}

---@param config rizu.skin.View.Config
function Hud:new(config)
	ViewContainer.new(self, config)
end

---Draws HUD views against the viewport dimensions and transform selected by the renderer.
---@param width number Native viewport width.
---@param height number Native viewport height.
---@param transform love.Transform Transform mapping viewport coordinates to drawable pixels.
function Hud:draw(width, height, transform)
	if not self.visible or width <= 0 or height <= 0 then return end
	ViewContainer.drawChildren(self, width, height, transform)
end

return Hud
