local View = require("gui.View")
local Painter = require("gui.Painter")

local lg = love.graphics

---An image layer that follows the mouse by depth times the parallax strength.
---@class ui.screens.main_menu.MainMenuBackground.Layer
---@field image love.Image
---@field depth number
---@field fit "fill"|"bottom" fill covers the screen, bottom fits the whole image and stands it on the bottom edge.

---Image layers, back to front, that follow the mouse.
---@class ui.screens.main_menu.MainMenuBackground : gui.View
---@operator call: ui.screens.main_menu.MainMenuBackground
---@field layers ui.screens.main_menu.MainMenuBackground.Layer[]
---@field parallax_strength number Offset in pixels of a layer with depth 1 at the screen edge.
---@field parallax_x number -1 to 1
---@field parallax_y number -1 to 1
local MainMenuBackground = View + {}

MainMenuBackground.parallax_smoothing = 5

---@param image love.Image
function MainMenuBackground:new(image)
	View.new(self)
	self:setLayers({{image = image, depth = 1, fit = "fill"}}, 10)
	self.parallax_x = 0
	self.parallax_y = 0
end

---@param layers ui.screens.main_menu.MainMenuBackground.Layer[]
---@param strength number
function MainMenuBackground:setLayers(layers, strength)
	self.layers = layers
	self.parallax_strength = strength
end

---@param dt number
function MainMenuBackground:update(dt)
	local mouse_x, mouse_y = love.mouse.getPosition()
	local local_x, local_y = self.world_transform:inverseTransformPoint(mouse_x, mouse_y)
	local target_x, target_y = 0, 0
	if self.width > 0 and self.height > 0 then
		target_x = math.max(-1, math.min(1, local_x / self.width * 2 - 1))
		target_y = math.max(-1, math.min(1, local_y / self.height * 2 - 1))
	end

	local smoothing = math.max(0, math.min(self.parallax_smoothing * dt, 1))
	self.parallax_x = self.parallax_x + (target_x - self.parallax_x) * smoothing
	self.parallax_y = self.parallax_y + (target_y - self.parallax_y) * smoothing
end

function MainMenuBackground:draw()
	local width, height = self.width, self.height
	Painter.setColorRgb(1, 1, 1)
	for _, layer in ipairs(self.layers) do
		local image = layer.image
		local image_width, image_height = image:getDimensions()
		-- The overscan is the layer's largest offset, so its edge never comes into view.
		local pad = layer.depth * self.parallax_strength
		local x = width * 0.5 + self.parallax_x * pad
		local y = self.parallax_y * pad
		if layer.fit == "bottom" then
			local scale = math.min(width / image_width, height / image_height)
			lg.draw(image, x, height + pad + y, 0, scale, scale, image_width * 0.5, image_height)
		else
			local scale = math.max((width + pad * 2) / image_width, (height + pad * 2) / image_height)
			lg.draw(image, x, height * 0.5 + y, 0, scale, scale, image_width * 0.5, image_height * 0.5)
		end
	end
end

return MainMenuBackground
