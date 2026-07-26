local View = require("gui.View")
local Painter = require("gui.Painter")
local SpringValue = require("gui.anim.SpringValue")

local lg = love.graphics

---@class ui.views.Background : gui.View
---@operator call: ui.views.Background
---@field model sphere.BackgroundModel
---@field parallax boolean
---@field parallax_x number
---@field parallax_y number
---@field target_parallax_x number
---@field target_parallax_y number
local Background = View + {}

Background.parallax_scale = 1.02
Background.parallax_strength = 10
Background.parallax_smoothing = 5

---@param model sphere.BackgroundModel
---@param parallax boolean?
function Background:new(model, parallax)
	View.new(self)
	self.model = model
	self.parallax = parallax == true
	self.parallax_x = 0
	self.parallax_y = 0
	self.target_parallax_x = 0
	self.target_parallax_y = 0
	self.brighness_spring = SpringValue({value = 1})
end

---@param v number
---@param immediate boolean 
function Background:setBrightness(v, immediate)
	if immediate then
		self.brighness_spring:snap(v)
	else
		self.brighness_spring:set(v)
	end
end

---@param dt number
function Background:update(dt)
	if not self.parallax then
		return
	end

	local mouse_x, mouse_y = love.mouse.getPosition()
	local local_x, local_y = self.world_transform:inverseTransformPoint(mouse_x, mouse_y)
	local norm_x, norm_y = 0, 0
	if self.width > 0 and self.height > 0 then
		norm_x = math.max(-1, math.min(1, local_x / self.width * 2 - 1))
		norm_y = math.max(-1, math.min(1, local_y / self.height * 2 - 1))
	end

	self.target_parallax_x = norm_x * self.parallax_strength
	self.target_parallax_y = norm_y * self.parallax_strength
	local smoothing = math.max(0, math.min(self.parallax_smoothing * dt, 1))
	self.parallax_x = self.parallax_x + (self.target_parallax_x - self.parallax_x) * smoothing
	self.parallax_y = self.parallax_y + (self.target_parallax_y - self.parallax_y) * smoothing

	self.brighness_spring:update(dt)
end

function Background:draw()
	local images = self.model.images
	if not images then
		return
	end

	local parallax_scale = self.parallax and self.parallax_scale or 1
	local offset_x = self.parallax and self.parallax_x or 0
	local offset_y = self.parallax and self.parallax_y or 0
	for i = 1, math.min(#images, 2) do
		local image = images[i]
		local image_width, image_height = image:getDimensions()
		local scale = math.max(self.width / image_width, self.height / image_height) * parallax_scale
		local alpha = i == 1 and 1 or self.model.alpha
		local b = self.brighness_spring:get()
		Painter.setColorRgb(b, b, b, alpha)
		lg.draw(
			image,
			self.width * 0.5 + offset_x,
			self.height * 0.5 + offset_y,
			0,
			scale,
			scale,
			image_width * 0.5,
			image_height * 0.5
		)
	end
end

return Background
