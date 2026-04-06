local Layer = require("ui.Layer")
local composition = require("ui.composition")
local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")
local PerformanceDisplay = require("yi.views.PerformanceDisplay")

---@class yi.MenuBackground : ui.Layer
---@operator call: yi.MenuBackground
local MenuBackground = Layer + {}

---@param yi yi.UserInterface
function MenuBackground:new(yi)
	Layer.new(self)
	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = PingPongBackground(image)
	self.code = CodeDecoration(yi.resources)
	self.performance = PerformanceDisplay(yi.resources, yi.game)
	self.composition_root = composition.Stack({
		self.background,
		self.code,
		self.performance,
	})
end

return MenuBackground
