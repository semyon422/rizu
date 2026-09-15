local View = require("gui.View")
local Painter = require("gui.Painter")

local lg = love.graphics

---@class ui.screens.main_menu.MainMenuBackground : gui.View
---@operator call: ui.screens.main_menu.MainMenuBackground
---@field image love.Image
---@field parallax_x number
---@field parallax_y number
local MainMenuBackground = View + {}

MainMenuBackground.parallax_scale = 1.02
MainMenuBackground.parallax_strength = 10
MainMenuBackground.parallax_smoothing = 5

---@param image love.Image
function MainMenuBackground:new(image)
	View.new(self)
	self.image = image
	self.parallax_x = 0
	self.parallax_y = 0
end

---@param dt number
function MainMenuBackground:update(dt)
	local mouse_x, mouse_y = love.mouse.getPosition()
	local local_x, local_y = self.world_transform:inverseTransformPoint(mouse_x, mouse_y)
	local target_x, target_y = 0, 0
	if self.width > 0 and self.height > 0 then
		target_x = math.max(-1, math.min(1, local_x / self.width * 2 - 1)) * self.parallax_strength
		target_y = math.max(-1, math.min(1, local_y / self.height * 2 - 1)) * self.parallax_strength
	end

	local smoothing = math.max(0, math.min(self.parallax_smoothing * dt, 1))
	self.parallax_x = self.parallax_x + (target_x - self.parallax_x) * smoothing
	self.parallax_y = self.parallax_y + (target_y - self.parallax_y) * smoothing
end

function MainMenuBackground:draw()
	local image_width, image_height = self.image:getDimensions()
	local scale = math.max(self.width / image_width, self.height / image_height) * self.parallax_scale
	Painter.setColorRgb(1, 1, 1)
	lg.draw(
		self.image,
		self.width * 0.5 + self.parallax_x,
		self.height * 0.5 + self.parallax_y,
		0,
		scale,
		scale,
		image_width * 0.5,
		image_height * 0.5
	)
end

return MainMenuBackground
