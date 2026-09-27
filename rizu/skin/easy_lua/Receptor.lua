local class = require("class")

---@class rizu.skin.easy_lua.Receptor.Config
---@field released love.Image? Image when its column input is not pressed.
---@field pressed love.Image? Image when its column input is pressed; falls back to released.
---@field scale_x number? Horizontal image scale; defaults to 1.
---@field scale_y number? Vertical image scale; defaults to 1.
---@field offset_x number? Horizontal offset from the column center; defaults to 0.
---@field offset_y number? Vertical offset from the hit position; defaults to 0.
---@field color number[]? Optional RGBA tint.

---@class rizu.skin.easy_lua.Receptor
---@operator call: rizu.skin.easy_lua.Receptor
---@field released love.Image?
---@field pressed love.Image?
---@field scale_x number
---@field scale_y number
---@field offset_x number
---@field offset_y number
---@field color number[]
local Receptor = class()

---@param config rizu.skin.easy_lua.Receptor.Config?
function Receptor:new(config)
	config = config or {}
	self.released = config.released
	self.pressed = config.pressed
	self.scale_x = config.scale_x or 1
	self.scale_y = config.scale_y or 1
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 0
	self.color = config.color or {1, 1, 1, 1}
	assert(self.scale_x == self.scale_x and math.abs(self.scale_x) < math.huge,
		"receptor scale_x must be finite")
	assert(self.scale_y == self.scale_y and math.abs(self.scale_y) < math.huge,
		"receptor scale_y must be finite")
	assert(self.offset_x == self.offset_x and math.abs(self.offset_x) < math.huge,
		"receptor offset_x must be finite")
	assert(self.offset_y == self.offset_y and math.abs(self.offset_y) < math.huge,
		"receptor offset_y must be finite")
	assert(type(self.color) == "table", "receptor color must be an RGBA table")
end

---@param x number Column centerline.
---@param hit_y number Column hit position.
---@param is_pressed boolean
function Receptor:draw(x, hit_y, is_pressed)
	local image = is_pressed and (self.pressed or self.released) or (self.released or self.pressed)
	if not image then return end
	if self.scale_x == 0 or self.scale_y == 0 then return end
	local width, height = image:getDimensions()
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
	love.graphics.draw(image, x + self.offset_x, hit_y + self.offset_y, 0,
		self.scale_x, self.scale_y, width / 2, height / 2)
end

---@param dt number
function Receptor:update(dt) end

return Receptor
