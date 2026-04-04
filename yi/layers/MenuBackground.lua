local Layer = require("ui.Layer")
local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")

---@class yi.MenuBackground : ui.Layer
---@operator call: yi.MenuBackground
local MenuBackground = Layer + {}

---@param yi yi.UserInterface
function MenuBackground:new(yi)
	Layer.new(self)
	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = self:add(PingPongBackground(image))
	self.code = self:add(CodeDecoration(yi.resources))
end

return MenuBackground
