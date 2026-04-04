local Layer = require("ui.Layer")
local ParallaxBackground = require("yi.views.ParallaxBackground")

---@class yi.Background : ui.Layer
---@operator call: yi.Background
local Background = Layer + {}

---@param yi yi.UserInterface
function Background:new(yi)
	Layer.new(self)

	local bg = ParallaxBackground(yi.game.backgroundModel)
	bg:setSizePercent(1, 1)
	bg:setAnchor(0.5, 0.5)
	bg:setOrigin(0.5, 0.5)
	self:add(bg)
end

return Background
