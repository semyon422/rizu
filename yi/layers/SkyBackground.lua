local Layer = require("ui.Layer")
local composition = require("ui.composition")
local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")

---@class yi.MenuBackground : ui.Layer
---@operator call: yi.MenuBackground
local SkyBackground = Layer + {}

---@param yi yi.UserInterface
function SkyBackground:new(yi)
	Layer.new(self)
	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = PingPongBackground(image)
	self.code = CodeDecoration(yi.resources)
	self.composition_root = composition.Stack({
		self.background,
		self.code,
	})
end

return SkyBackground
