local Layer = require("ui.Layer")
local S = require("ui.composition.Strategies")
local ParallaxBackground = require("yi.views.ParallaxBackground")

---@class yi.Background : ui.Layer
---@operator call: yi.Background
local Background = Layer + {}

---@param yi yi.UserInterface
function Background:new(yi)
	Layer.new(self)
	local bg = ParallaxBackground(yi.game.backgroundModel)
	self.composition:setRoot(S.Stack({bg}))
end

return Background
