local View = require("gui.View")

---@class yi.ParallaxBackground : gui.View
---@overload fun(background_model: sphere.BackgroundModel): yi.ParallaxBackground
local ParallaxBackground = View + {}

ParallaxBackground.parallax_scale = 1.02
ParallaxBackground.parallax_strength = 10 -- Maximum offset in pixels
ParallaxBackground.parallax_smoothing = 5

---@param background_model sphere.BackgroundModel
function ParallaxBackground:new(background_model)
	View.new(self)
	self.background_model = background_model

	self.parallax_x = 0
	self.parallax_y = 0
	self.target_parallax_x = 0
	self.target_parallax_y = 0

	self.dim = 0.5
	self.target_dim = 0.5
	self.dim_smoothing = 5
end

---@param dim number
function ParallaxBackground:setDim(dim)
	self.target_dim = dim
end

---@param dt number
function ParallaxBackground:update(dt)
	local mx, my = love.mouse.getPosition()
	local imx, imy = self.transform:inverseTransformPoint(mx, my)
	local w, h = self.box:getDimensions()

	local norm_x = 0
	local norm_y = 0

	if w > 0 and h > 0 then
		norm_x = (imx / w) * 2 - 1
		norm_y = (imy / h) * 2 - 1

		norm_x = math.max(-1, math.min(1, norm_x))
		norm_y = math.max(-1, math.min(1, norm_y))

		if norm_x ~= norm_x then norm_x = 0 end
		if norm_y ~= norm_y then norm_y = 0 end
	end

	self.target_parallax_x = norm_x * self.parallax_strength
	self.target_parallax_y = norm_y * self.parallax_strength

	local smoothing = math.max(0, math.min(self.parallax_smoothing * dt, 1))
	if smoothing ~= smoothing then smoothing = 0 end

	self.parallax_x = self.parallax_x + (self.target_parallax_x - self.parallax_x) * smoothing
	self.parallax_y = self.parallax_y + (self.target_parallax_y - self.parallax_y) * smoothing

	local s = self.parallax_strength
	self.parallax_x = math.max(-s, math.min(s, self.parallax_x))
	self.parallax_y = math.max(-s, math.min(s, self.parallax_y))

	if self.parallax_x ~= self.parallax_x then self.parallax_x = 0 end
	if self.parallax_y ~= self.parallax_y then self.parallax_y = 0 end

	local dim_smoothing = math.max(0, math.min(self.dim_smoothing * dt, 1))
	if dim_smoothing ~= dim_smoothing then dim_smoothing = 0 end
	self.dim = self.dim + (self.target_dim - self.dim) * dim_smoothing
end

function ParallaxBackground:draw()
	local images = self.background_model.images
	local alpha = self.background_model.alpha
	local dim = 1 - self.dim
	local w, h = self.box:getDimensions()

	for i = 1, 3 do
		if not images[i] then
			return
		end

		if i == 1 then
			love.graphics.setColor(dim, dim, dim, 1)
		elseif i == 2 then
			love.graphics.setColor(dim, dim, dim, alpha)
		elseif i == 3 then
			love.graphics.setColor(dim, dim, dim, 0)
		end

		local img = images[i]
		local iw, ih = img:getDimensions()

		local s = math.max(h / ih, w / iw) * self.parallax_scale
		love.graphics.draw(img, w / 2 + self.parallax_x, h / 2 + self.parallax_y, 0, s, s, iw / 2, ih / 2)
	end
end

return ParallaxBackground
