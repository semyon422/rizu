local class = require("class")
local ScrollPhysics = require("yi.views.scroll_list.ScrollPhysics")

---@alias yi.ScrollCameraState "idle" | "dragging" | "momentum" | "returning" | "tweening"

---@class yi.ScrollCamera
---@operator call: yi.ScrollCamera
---@field position number Current visual scroll position
---@field velocity number Current scroll velocity
---@field target number? Target position when returning to bounds or tweening
---@field state yi.ScrollCameraState
---@field physics yi.ScrollPhysics
---@field min_position number Minimum allowed position (default 1)
---@field max_position number Maximum allowed position (set dynamically)
---@field tween_start number? Start position for linear tween
---@field tween_progress number Progress through the tween (0 to 1)
local ScrollCamera = class()

function ScrollCamera:new()
	self.position = 1
	self.velocity = 0
	self.target = nil
	self.state = "idle"
	self.physics = ScrollPhysics()
	self.min_position = 1
	self.max_position = 1
	self.tween_start = nil
	self.tween_progress = 0
end

---Set the bounds for the camera position
---@param min number
---@param max number
function ScrollCamera:setBounds(min, max)
	self.min_position = min
	self.max_position = math.max(min, max)
end

---@return boolean
function ScrollCamera:isOutOfBounds()
	return self.position < self.min_position or self.position > self.max_position
end

---Get the nearest bound if out of bounds
---@return number
function ScrollCamera:getNearestBound()
	if self.position < self.min_position then
		return self.min_position
	elseif self.position > self.max_position then
		return self.max_position
	end
	return self.position
end

---Start a linear tween to a target position
---@param target number
function ScrollCamera:tweenTo(target)
	-- Clamp target to bounds
	target = math.max(self.min_position, math.min(self.max_position, target))

	self.tween_start = self.position
	self.target = target
	self.tween_progress = 0
	self.velocity = 0
	self.state = "tweening"
end

---Tween by a delta amount (accumulates if already tweening)
---@param delta number
function ScrollCamera:tweenBy(delta)
	local target
	if self.state == "tweening" and self.target then
		-- Already tweening - accumulate from current target
		target = self.target + delta
	else
		-- Not tweening - start from current position
		target = self.position + delta
	end

	self:tweenTo(target)
end

---Start dragging mode
function ScrollCamera:startDrag()
	self.state = "dragging"
	self.target = nil
end

---End dragging and transition to momentum or returning
---@param velocity number
function ScrollCamera:endDrag(velocity)
	self.velocity = velocity

	if self:isOutOfBounds() then
		-- If already out of bounds, just return (don't apply velocity)
		self.velocity = 0
		self.state = "returning"
		self.target = self:getNearestBound()
	elseif math.abs(self.velocity) < self.physics.min_velocity then
		self.state = "idle"
		self.velocity = 0
	else
		self.state = "momentum"
	end
end

---@param dt number
function ScrollCamera:update(dt)
	local physics = self.physics

	if self.state == "idle" then
		self.velocity = 0
	elseif self.state == "dragging" then
		-- Velocity is set externally during drag
		-- Apply overscroll resistance
		if self:isOutOfBounds() then
			self.velocity = self.velocity * physics.overscroll_resistance
		end
	elseif self.state == "momentum" then
		-- Apply friction
		self.velocity = self.velocity * math.pow(physics.momentum_friction, dt * 60)
		self.position = self.position + self.velocity * dt

		-- Check if we've gone out of bounds - transition to returning
		if self:isOutOfBounds() then
			self.velocity = 0 -- Reset velocity when transitioning to returning
			self.state = "returning"
			self.target = self:getNearestBound()
		elseif math.abs(self.velocity) < physics.min_velocity then
			-- Transition to idle if velocity is too low
			self.state = "idle"
			self.velocity = 0
		end

	elseif self.state == "returning" then
		-- Simple lerp back to bounds
		if self.target then
			local diff = self.target - self.position
			self.position = self.position + diff * math.min(1, dt * physics.lerp_return_speed)

			-- Check if we've returned
			if math.abs(diff) < 0.01 then
				self.position = self.target
				self.velocity = 0
				self.target = nil
				self.state = "idle"
			end
		else
			self.target = self:getNearestBound()
		end

	elseif self.state == "tweening" then
		-- Linear tween to target
		if self.target and self.tween_start then
			-- Advance progress (0.25 seconds total duration)
			self.tween_progress = self.tween_progress + dt / physics.tween_duration

			if self.tween_progress >= 1 then
				-- Tween complete
				self.position = self.target
				self.velocity = 0
				self.target = nil
				self.tween_start = nil
				self.tween_progress = 0
				self.state = "idle"
			else
				-- Linear interpolation
				self.position = self.tween_start + (self.target - self.tween_start) * self.tween_progress
			end
		else
			self.state = "idle"
		end
	end
end

---Interrupt current state (e.g., when user starts dragging during animation)
function ScrollCamera:interrupt()
	self.target = nil
	self.velocity = 0
end

return ScrollCamera
