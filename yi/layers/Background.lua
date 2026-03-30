local Layer = require("ui.Layer")
local ParallaxBackground = require("yi.views.ParallaxBackground")

---@class yi.Background : ui.Layer
---@operator call: yi.Background
local Background = Layer + {}

---@param ctx yi.Context
function Background:new(ctx)
	Layer.new(self)

	local bg = ParallaxBackground(ctx.game.backgroundModel)
	bg.width_percent = 1
	bg.height_percent = 1
	bg.anchor = {0.5, 0.5}
	bg.origin = {0.5, 0.5}
	self:add(bg)
end

return Background
