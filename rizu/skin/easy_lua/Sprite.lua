local class = require("class")

---@class rizu.skin.easy_lua.Sprite.Config
---@field image love.Image Image to draw.
---@field x number? Native-space center X; defaults to 0.
---@field y number? Native-space center Y; defaults to 0.
---@field scale_x number? Horizontal image scale; defaults to 1.
---@field scale_y number? Vertical image scale; defaults to 1.
---@field offset_x number? Additional draw offset from x; defaults to 0.
---@field offset_y number? Additional draw offset from y; defaults to 0.
---@field rotation number? Rotation in radians; defaults to 0.
---@field origin_x number? Normalized horizontal origin in [0, 1]; defaults to 0.5.
---@field origin_y number? Normalized vertical origin in [0, 1]; defaults to 0.5.
---@field color number[]? Optional RGB or RGBA tint; defaults to white.

---@class rizu.skin.easy_lua.Sprite
---@operator call: rizu.skin.easy_lua.Sprite
---@field image love.Image
---@field x number
---@field y number
---@field scale_x number
---@field scale_y number
---@field offset_x number
---@field offset_y number
---@field rotation number
---@field origin_x number
---@field origin_y number
---@field color number[]
local Sprite = class()

---@param config rizu.skin.easy_lua.Sprite.Config
function Sprite:new(config)
	assert(type(config) == "table" and config.image, "sprite image is required")
	self.image = config.image
	self.x = config.x or 0
	self.y = config.y or 0
	self.scale_x = config.scale_x or 1
	self.scale_y = config.scale_y or 1
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 0
	self.rotation = config.rotation or 0
	self.origin_x = config.origin_x or 0.5
	self.origin_y = config.origin_y or 0.5
	self.color = config.color or {1, 1, 1, 1}

	assert(type(self.x) == "number" and self.x == self.x and math.abs(self.x) < math.huge,
		"sprite x must be finite")
	assert(type(self.y) == "number" and self.y == self.y and math.abs(self.y) < math.huge,
		"sprite y must be finite")
	assert(type(self.scale_x) == "number" and self.scale_x == self.scale_x and math.abs(self.scale_x) < math.huge,
		"sprite scale_x must be finite")
	assert(type(self.scale_y) == "number" and self.scale_y == self.scale_y and math.abs(self.scale_y) < math.huge,
		"sprite scale_y must be finite")
	assert(type(self.offset_x) == "number" and self.offset_x == self.offset_x and math.abs(self.offset_x) < math.huge,
		"sprite offset_x must be finite")
	assert(type(self.offset_y) == "number" and self.offset_y == self.offset_y and math.abs(self.offset_y) < math.huge,
		"sprite offset_y must be finite")
	assert(type(self.rotation) == "number" and self.rotation == self.rotation and math.abs(self.rotation) < math.huge,
		"sprite rotation must be finite")
	assert(type(self.origin_x) == "number" and self.origin_x == self.origin_x
		and self.origin_x >= 0 and self.origin_x <= 1, "sprite origin_x must be between 0 and 1")
	assert(type(self.origin_y) == "number" and self.origin_y == self.origin_y
		and self.origin_y >= 0 and self.origin_y <= 1, "sprite origin_y must be between 0 and 1")
	assert(type(self.color) == "table" and #self.color >= 3 and #self.color <= 4,
		"sprite color must be RGB or RGBA")
	for i = 1, #self.color do
		local channel = self.color[i]
		assert(type(channel) == "number" and channel == channel and channel >= 0 and channel <= 1,
			"sprite color channels must be between 0 and 1")
	end
end

---Draw at the configured native-space center, optionally overriding either coordinate.
---@param x number? Center X override.
---@param y number? Center Y override.
function Sprite:draw(x, y)
	local width, height = self.image:getDimensions()
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	love.graphics.draw(self.image, (x or self.x) + self.offset_x, (y or self.y) + self.offset_y,
		self.rotation, self.scale_x, self.scale_y, width * self.origin_x, height * self.origin_y)
end

---@param _dt number
function Sprite:update(_dt) end

return Sprite
