local class = require("class")

---@class rizu.skin.easy_lua.HitLighting.Config
---@field image love.Image Image displayed when triggered.
---@field width number? Full animation width in native units; defaults to the image width.
---@field scale_y number? Vertical image scale; defaults to 1.
---@field offset_x number? Offset from the column center; defaults to 0.
---@field offset_y number? Offset from the hit position; defaults to 0.
---@field duration number? Animation duration in seconds; defaults to 0.2.
---@field color number[]? RGBA tint; defaults to white with 0.15 alpha.

---@class rizu.skin.easy_lua.HitLighting
---@operator call: rizu.skin.easy_lua.HitLighting
---@field image love.Image
---@field width number
---@field scale_y number
---@field offset_x number
---@field offset_y number
---@field duration number
---@field color number[]
---@field elapsed number
---@field active boolean
local HitLighting = class()

---@param config rizu.skin.easy_lua.HitLighting.Config
function HitLighting:new(config)
	assert(type(config) == "table" and config.image, "hit lighting image is required")
	self.image = config.image
	local image_width = self.image:getWidth()
	self.width = config.width or image_width
	self.scale_y = config.scale_y or 1
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 0
	self.duration = config.duration or 0.2
	self.color = config.color or {1, 1, 1, 0.15}
	self.elapsed = 0
	self.active = false

	assert(type(self.width) == "number" and self.width > 0 and self.width < math.huge,
		"hit lighting width must be positive and finite")
	assert(type(self.scale_y) == "number" and self.scale_y == self.scale_y and math.abs(self.scale_y) < math.huge,
		"hit lighting scale_y must be finite")
	assert(type(self.offset_x) == "number" and self.offset_x == self.offset_x and math.abs(self.offset_x) < math.huge,
		"hit lighting offset_x must be finite")
	assert(type(self.offset_y) == "number" and self.offset_y == self.offset_y and math.abs(self.offset_y) < math.huge,
		"hit lighting offset_y must be finite")
	assert(type(self.duration) == "number" and self.duration > 0 and self.duration < math.huge,
		"hit lighting duration must be positive and finite")
	assert(type(self.color) == "table" and #self.color >= 3 and #self.color <= 4,
		"hit lighting color must be RGB or RGBA")
	for i = 1, #self.color do
		local channel = self.color[i]
		assert(type(channel) == "number" and channel == channel and channel >= 0 and channel <= 1,
			"hit lighting color channels must be between 0 and 1")
	end
end

function HitLighting:trigger()
	self.elapsed = 0
	self.active = true
end

---@param dt number
function HitLighting:update(dt)
	if not self.active then return end
	self.elapsed = self.elapsed + dt
	if self.elapsed >= self.duration then
		self.elapsed = self.duration
		self.active = false
	end
end

---@param x number Column centerline.
---@param hit_y number Column hit position.
function HitLighting:draw(x, hit_y)
	if not self.active then return end
	local progress = math.min(self.elapsed / self.duration, 1)
	-- OutQuad shrinking: full width at trigger, smoothly collapsing to zero.
	local width_factor = (1 - progress) * (1 - progress)
	local image_width, image_height = self.image:getDimensions()
	local scale_x = self.width / image_width * width_factor
	if scale_x <= 0 then return end
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	love.graphics.draw(self.image, x + self.offset_x, hit_y + self.offset_y, 0,
		scale_x, self.scale_y, image_width / 2, image_height / 2)
end

return HitLighting
