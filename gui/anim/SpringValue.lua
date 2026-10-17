local IValue = require("gui.anim.IValue")

---@class gui.anim.SpringValue.Config
---@field value? number
---@field target? number
---@field velocity? number
---@field stiffness? number
---@field damping? number
---@field epsilon? number
---@field max_step? number

---@class gui.anim.SpringValue: gui.anim.IValue
---@overload fun(config: gui.anim.SpringValue.Config?): gui.anim.SpringValue
---@field value number
---@field target number
---@field velocity number
---@field stiffness number
---@field damping number
---@field epsilon number
---@field max_step number
local SpringValue = IValue + {}

---@param self gui.anim.SpringValue
local function settle_if_close(self)
	if math.abs(self.target - self.value) <= self.epsilon and math.abs(self.velocity) <= self.epsilon then
		self.value = self.target
		self.velocity = 0
	end
end

---@param config gui.anim.SpringValue.Config?
function SpringValue:new(config)
	self.value = 0
	self.target = 0
	self.velocity = 0
	self.stiffness = 240
	self.damping = 28
	self.epsilon = 0.0001
	self.max_step = 1 / 120

	self:configure(config)

	local value = config and config.value or 0
	self.value = value
	self.target = value
	self.velocity = config and config.velocity or 0

	if config and config.target ~= nil then
		self:set(config.target)
	end
end

---@param config gui.anim.SpringValue.Config?
---@return self
function SpringValue:configure(config)
	if not config then
		return self
	end

	if config.stiffness ~= nil then
		assert(config.stiffness >= 0, "stiffness must be non-negative")
		self.stiffness = config.stiffness
	end
	if config.damping ~= nil then
		assert(config.damping >= 0, "damping must be non-negative")
		self.damping = config.damping
	end
	if config.epsilon ~= nil then
		assert(config.epsilon >= 0, "epsilon must be non-negative")
		self.epsilon = config.epsilon
	end
	if config.max_step ~= nil then
		assert(config.max_step > 0, "max_step must be positive")
		self.max_step = config.max_step
	end
	if config.velocity ~= nil then
		self.velocity = config.velocity
	end

	return self
end

---@param target number
---@return self
function SpringValue:set(target)
	self.target = target
	settle_if_close(self)
	return self
end

---@param value? number
---@return self
function SpringValue:snap(value)
	value = value == nil and self.target or value
	self.value = value
	self.target = value
	self.velocity = 0
	return self
end

---@return number
function SpringValue:get()
	return self.value
end

---@return boolean
function SpringValue:isAnimating()
	return self.value ~= self.target or self.velocity ~= 0
end

---@param dt number
---@return number
function SpringValue:update(dt)
	if dt <= 0 then
		return self.value
	end

	local remaining = dt
	while remaining > 0 do
		local step = math.min(remaining, self.max_step)
		local displacement = self.target - self.value
		local acceleration = displacement * self.stiffness - self.velocity * self.damping
		self.velocity = self.velocity + acceleration * step
		self.value = self.value + self.velocity * step
		remaining = remaining - step
	end

	settle_if_close(self)
	return self.value
end

return SpringValue
