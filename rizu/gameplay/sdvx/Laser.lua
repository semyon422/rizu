local class = require("class")

---@class rizu.sdvx.Laser
---@operator call: rizu.sdvx.Laser
---@field chain chart.ksm.SdvxLaser
---@field slams {[integer]: "hit"|"miss"}
---@field ticks {time: number, hit: boolean}[]
local Laser = class()
Laser.step = 1 / 240
Laser.tolerance = 0.08
Laser.keyboard_speed = 2
Laser.slam_window = 0.075

---@param value number
---@return number
local function sign(value)
	return value > 0 and 1 or value < 0 and -1 or 0
end

---@param chain chart.ksm.SdvxLaser
function Laser:new(chain)
	assert(#chain.segments > 0)
	self.chain = chain
	self.position = chain.segments[1].from
	self.direction = 0
	self.captured = false
	self.hits, self.misses, self.slam_hits, self.slam_misses = 0, 0, 0, 0
	self.slams, self.ticks = {}, {}
	self.sample = 0
	self.segment_index = 1
	self.time = chain.segments[1].time - self.step
	self.input_time = -math.huge
end

---@param time number
function Laser:update(time)
	local segments = self.chain.segments
	local start = segments[1].time
	local ending = segments[#segments].end_time
	while start + self.sample * self.step < time and start + self.sample * self.step <= ending do
		local now = start + self.sample * self.step
		local segment = segments[self.segment_index]
		while self.segment_index < #segments and segment.end_time < now do
			self.segment_index = self.segment_index + 1
			segment = segments[self.segment_index]
		end
		if not segment.slam then
			local duration = segment.end_time - segment.time
			local progress = duration == 0 and 1 or math.max(0, math.min(1, (now - segment.time) / duration))
			local target = segment.from + (segment.to - segment.from) * progress
			local slope = sign(segment.to - segment.from)
			local delta = self.direction * self.keyboard_speed * self.step
			if slope == 0 and (self.segment_index == 1 or math.abs(self.position - target) <= self.tolerance) then
				self.position = target
			elseif self.direction ~= 0 then
				local difference = target - self.position
				if sign(delta) == sign(difference) and math.abs(delta) >= math.abs(difference) then
					self.position = target
				else
					self.position = math.max(0, math.min(1, self.position + delta))
				end
				if self.direction == slope and math.abs(self.position - target) <= self.tolerance then self.position = target end
			end
			self.captured = math.abs(self.position - target) <= self.tolerance
			-- Fixed chart-time checkpoints, not render updates.
			if self.sample % 15 == 0 then
				self.ticks[#self.ticks + 1] = {time = now, hit = self.captured}
				if self.captured then self.hits = self.hits + 1 else self.misses = self.misses + 1 end
			end
		end
		self.time = now
		self.sample = self.sample + 1
	end
	for i, segment in ipairs(segments) do
		if segment.slam and not self.slams[i] and segment.time + self.slam_window < time then
			self.slams[i] = "miss"
			self.slam_misses = self.slam_misses + 1
		end
	end
end

---@param direction integer -1, 0 or 1. A state transition, not an automatic slam hit.
---@param time number
function Laser:setDirection(direction, time)
	assert(direction == -1 or direction == 0 or direction == 1)
	self:update(time)
	self.direction = direction
	self.input_time = time
end

---@param delta number Relative knob displacement, or a keyboard direction edge.
---@param time number
---@param paused boolean?
function Laser:turn(delta, time, paused)
	assert(delta == delta and math.abs(delta) < math.huge)
	self:update(time)
	if paused or delta == 0 then return end
	local segments = self.chain.segments
	if time < segments[1].time - self.slam_window or time > segments[#segments].end_time + self.slam_window then return end
	for i, segment in ipairs(segments) do
		if segment.slam and not self.slams[i] and math.abs(time - segment.time) <= self.slam_window
			and sign(delta) == sign(segment.to - segment.from) then
			self.slams[i] = "hit"
			self.slam_hits = self.slam_hits + 1
			self.position = segment.to
			self.captured = true
			return
		end
	end
	if time >= segments[1].time and time <= segments[#segments].end_time then
		self.position = math.max(0, math.min(1, self.position + delta))
	end
end

return Laser
