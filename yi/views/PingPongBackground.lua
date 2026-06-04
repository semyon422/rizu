local View = require("gui.View")

---@class yi.PingPongBackground : gui.View
---@overload fun(image: love.Image): yi.PingPongBackground
local PingPongBackground = View + {}

---@param t number
---@param length number
---@return number
local function ping_pong(t, length)
	if length <= 0 then
		return 0
	end
	local cycle = t % (length * 2)
	if cycle > length then
		return length * 2 - cycle
	end
	return cycle
end

---@param t number
---@param length number
---@return number
local function smooth_ping_pong(t, length)
	if length <= 0 then
		return 0
	end
	local p = ping_pong(t, length) / length
	local eased = p * p * (3 - 2 * p)
	return eased * length
end

---@param image love.Image
function PingPongBackground:new(image)
	View.new(self)
	self.image = assert(image)
	self.scale_factor = 1.35
	self.speed_x = 18
	self.speed_y = 12
	self.time = 0
	self.width_percent = 1
	self.height_percent = 1
	self.alpha = 1
end

---@param dt number
function PingPongBackground:update(dt)
	self.time = self.time + dt
end

function PingPongBackground:draw()
	local lg = love.graphics
	local ww, wh = self.box.width, self.box.height
	local iw, ih = self.image:getDimensions()
	local cover_scale = math.max(ww / iw, wh / ih) * self.scale_factor
	local scaled_w = iw * cover_scale
	local scaled_h = ih * cover_scale
	local overflow_x = math.max(0, scaled_w - ww)
	local overflow_y = math.max(0, scaled_h - wh)
	local x = -smooth_ping_pong(self.time * self.speed_x, overflow_x)
	local y = -smooth_ping_pong(self.time * self.speed_y, overflow_y)

	lg.push("all")
	lg.setColor(1, 1, 1, self.alpha)
	lg.draw(self.image, x, y, 0, cover_scale, cover_scale)
	lg.pop()
end

return PingPongBackground
