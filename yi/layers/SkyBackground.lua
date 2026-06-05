local Layer = require("gui.Layer")
local S = require("gui.composition.Strategies")
local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")

---@class yi.MenuBackground : gui.Layer
---@operator call: yi.MenuBackground
local SkyBackground = Layer + {}

---@param yi yi.UserInterface
function SkyBackground:new(yi)
	Layer.new(self)
	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = PingPongBackground(image)
	self.code = CodeDecoration()
	self.composition:setRoot(S.Stack({
		self.background,
		self.code,
	}))
end

return SkyBackground
