local IValue = require("gui.anim.IValue")
local math_util = require("math_util")

---@class gui.anim.TweenValue.Config
---@field value? number
---@field target? number
---@field velocity? number
---@field duration? number
---@field speed? number
---@field easing? gui.anim.ValueEasing

---@class gui.anim.TweenValue: gui.anim.IValue
---@overload fun(config: gui.anim.TweenValue.Config?): gui.anim.TweenValue
---@field value number
---@field target number
---@field velocity number
---@field duration number?
---@field speed number?
---@field easing fun(t: number): number
local TweenValue = IValue + {}

local easings = {
	linear = function(t)
		return t
	end,
	inQuad = function(t)
		return t * t
	end,
	outQuad = function(t)
		return 1 - (1 - t) * (1 - t)
	end,
	inOutQuad = function(t)
		if t < 0.5 then
			return 2 * t * t
		end
		return 1 - ((-2 * t + 2) ^ 2) * 0.5
	end,
	outCubic = function(t)
		return 1 - (1 - t) ^ 3
	end,
	inOutCubic = function(t)
		if t < 0.5 then
			return 4 * t * t * t
		end
		return 1 - ((-2 * t + 2) ^ 3) * 0.5
	end,
}

---@param easing gui.anim.ValueEasing?
---@return fun(t: number): number
local function resolve_easing(easing)
	if easing == nil then
		return easings.linear
	end
	if type(easing) == "function" then
		return easing
	end
	local resolved = easings[easing]
	assert(resolved, ("unknown easing: %s"):format(tostring(easing)))
	return resolved
end

---@param self gui.anim.TweenValue
---@param distance number
---@return number
local function resolve_duration(self, distance)
	local duration = self.duration
	if duration ~= nil then
		return duration
	end

	local speed = self.speed
	if not speed or speed <= 0 then
		return 0
	end

	return distance / speed
end

---@param self gui.anim.TweenValue
local function stop(self)
	self._from = self.value
	self._elapsed = 0
	self._duration = 0
end

---@param config gui.anim.TweenValue.Config?
function TweenValue:new(config)
	self.value = 0
	self.target = 0
	self.velocity = 0
	self.duration = nil
	self.speed = nil
	self.easing = easings.linear
	self._from = 0
	self._elapsed = 0
	self._duration = 0

	self:configure(config)

	local value = config and config.value or 0
	self.value = value
	self.target = value
	self._from = value
	self.velocity = config and config.velocity or 0

	if config and config.target ~= nil then
		self:set(config.target)
	end
end

---@param config gui.anim.TweenValue.Config?
---@return self
function TweenValue:configure(config)
	if not config then
		return self
	end

	if config.duration ~= nil then
		assert(config.duration >= 0, "duration must be non-negative")
		self.duration = config.duration
	end
	if config.speed ~= nil then
		assert(config.speed >= 0, "speed must be non-negative")
		self.speed = config.speed
	end
	if config.easing ~= nil then
		self.easing = resolve_easing(config.easing)
	end
	if config.velocity ~= nil then
		self.velocity = config.velocity
	end

	return self
end

---@param target number
---@return self
function TweenValue:set(target)
	self._from = self.value
	self._elapsed = 0
	self._duration = resolve_duration(self, math.abs(target - self.value))
	self.target = target

	if self._duration == 0 then
		self:snap(target)
	end

	return self
end

---@param value? number
---@return self
function TweenValue:snap(value)
	if not value then
		value = self.target
	end
	self.value = value
	self.target = value
	self.velocity = 0
	stop(self)
	return self
end

---@return number
function TweenValue:get()
	return self.value
end

---@return boolean
function TweenValue:isAnimating()
	return self.value ~= self.target
end

---@param dt number
---@return number
function TweenValue:update(dt)
	if dt <= 0 then
		return self.value
	end

	if self.value == self.target then
		return self.value
	end

	local duration = self._duration
	if duration <= 0 then
		self:snap(self.target)
		return self.value
	end

	self._elapsed = math.min(self._elapsed + dt, duration)
	local progress = self._elapsed / duration
	self.value = math_util.lerp(self.easing(progress), self._from, self.target)
	if self._elapsed >= duration then
		self.value = self.target
		stop(self)
	end
	return self.value
end

return TweenValue
