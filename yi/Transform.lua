local class = require("class")
local math_util = require("math_util")

---@class yi.Transform
---@field x number
---@field y number
---@field angle number
---@field scale_x number
---@field scale_y number
---@field origin_x number -- 0 - 1
---@field origin_y number -- 0 - 1
---@field anchor_x number -- 0 - 1
---@field anchor_y number -- 0 - 1
---@field dirty boolean 
---@field love_transform love.Transform
local Transform = class()

-- NOTE: The dirty flag is for internal Engine optimization. 
-- Do not rely on it for gameplay logic.

function Transform:new()
	self.x = 0
	self.y = 0
	self.angle = 0
	self.scale_x = 1
	self.scale_y = 1
	self.origin_x = 0
	self.origin_y = 0
	self.anchor_x = 0
	self.anchor_y = 0
	self.dirty = true
	self.love_transform = math_util.newTransform()
end

local temp_tf = math_util.newTransform()

---@param layout_box ui.LayoutBox
---@param parent_transform love.Transform?
---@param parent_layout_box ui.LayoutBox?
function Transform:update(layout_box, parent_transform, parent_layout_box)
	local x_axis = layout_box.x
	local y_axis = layout_box.y
	local ox = self.origin_x * x_axis.size
	local oy = self.origin_y * y_axis.size

	if parent_transform and parent_layout_box then
		local ax = x_axis.pos + self.anchor_x * parent_layout_box.x.size
		local ay = y_axis.pos + self.anchor_y * parent_layout_box.y.size

		self.love_transform:reset()
		self.love_transform:apply(parent_transform)
		temp_tf:setTransformation(
			ax + self.x,
			ay + self.y,
			self.angle,
			self.scale_x,
			self.scale_y,
			ox,
			oy
		)
		self.love_transform:apply(temp_tf)
	else
		self.love_transform:setTransformation(
			x_axis.pos + self.x,
			y_axis.pos + self.y,
			self.angle,
			self.scale_x,
			self.scale_y,
			ox,
			oy
		)
	end

	self.dirty = false
end

---@param x number
---@param y number
---@return number
---@return number
function Transform:inverseTransformPoint(x, y)
	return self.love_transform:inverseTransformPoint(x, y)
end

function Transform:setX(v)
	if self.x ~= v then
		self.x = v
		self.dirty = true
	end
end

function Transform:setY(v)
	if self.y ~= v then
		self.y = v
		self.dirty = true
	end
end

function Transform:setAngle(v)
	if self.angle ~= v then
		self.angle = v
		self.dirty = true
	end
end

function Transform:setScaleX(v)
	if self.scale_x ~= v then
		self.scale_x = v
		self.dirty = true
	end
end

function Transform:setScaleY(v)
	if self.scale_y ~= v then
		self.scale_y = v
		self.dirty = true
	end
end

function Transform:setOriginX(v)
	if self.origin_x ~= v then
		self.origin_x = v
		self.dirty = true
	end
end

function Transform:setOriginY(v)
	if self.origin_y ~= v then
		self.origin_y = v
		self.dirty = true
	end
end

function Transform:setAnchorX(v)
	if self.anchor_x ~= v then
		self.anchor_x = v
		self.dirty = true
	end
end

function Transform:setAnchorY(v)
	if self.anchor_y ~= v then
		self.anchor_y = v
		self.dirty = true
	end
end

function Transform:setOrigin(x, y)
	self:setOriginX(x)
	self:setOriginY(y)
end

function Transform:setAnchor(x, y)
	self:setAnchorX(x)
	self:setAnchorY(y)
end

function Transform:setScale(x, y)
	self:setScaleX(x)
	self:setScaleY(y or x)
end

function Transform:setPosition(x, y)
	self:setX(x)
	self:setY(y)
end

return Transform
