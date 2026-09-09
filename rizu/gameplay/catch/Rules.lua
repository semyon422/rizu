local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.catch.Judgement
---@field index integer
---@field time number
---@field hit boolean
---@field x number

---@class rizu.catch.Rules
---@operator call: rizu.catch.Rules
---@field chart chart.osu.CatchChart
---@field buttons {[integer]: boolean}
---@field states ("hit"|"miss")[]
---@field events rizu.catch.Judgement[]
---@field hyper_targets {[integer]: integer}
local Rules = class()
Rules.walk_speed = 500
Rules.dash_speed = 1000
Rules.window = 0

---@param chart chart.osu.CatchChart
function Rules:new(chart)
	assert(#chart.objects > 0, "Catch prototype: empty chart.")
	self.chart = chart
	self.half_width = (54.4 - 4.48 * chart.circle_size) * 0.8
	local ar = chart.approach_rate
	self.preempt = ar < 5 and 1.8 - 0.12 * ar or 1.2 - 0.15 * (ar - 5)
	self.x, self.time = 256, math.min(0, chart.objects[1].time - self.preempt)
	self.motion_x, self.motion_time = self.x, self.time
	self.buttons, self.states, self.events, self.hyper_targets = {}, {}, {}, {}
	self.next_index, self.hits, self.misses = 1, 0, 0
	self.bonus_hits, self.bonus_misses = 0, 0
	self.hyper_until, self.hyper_speed = -math.huge, self.dash_speed
	---@type integer?
	local previous
	for i, object in ipairs(chart.objects) do
		if object.kind == "fruit" or object.kind == "droplet" then
			if previous then
				local from = chart.objects[previous]
				if math.abs(object.x - from.x) > self.dash_speed * (object.time - from.time) + self.half_width then
					self.hyper_targets[previous] = i
				end
			end
			previous = i
		end
	end
end

---@return number
function Rules:direction()
	local left = self.buttons[1] or self.buttons[4]
	local right = self.buttons[2] or self.buttons[5]
	return (right and 1 or 0) - (left and 1 or 0)
end

---@return boolean
function Rules:isDash()
	return not not (self.buttons[3] or self.buttons[6])
end

---@return number
function Rules:speed()
	if self.time < self.hyper_until then return self.hyper_speed end
	return self:isDash() and self.dash_speed or self.walk_speed
end

---@param time number
function Rules:moveTo(time)
	if time <= self.time then return end
	local split = math.max(self.motion_time, math.min(time, self.hyper_until))
	local direction = self:direction()
	local boosted = direction * self.hyper_speed * (split - self.motion_time)
	local normal = direction * (self:isDash() and self.dash_speed or self.walk_speed) * (time - split)
	self.x = math.max(0, math.min(512, self.motion_x + boosted + normal))
	self.time = time
end

---@param time number
function Rules:update(time)
	if time < self.time and not self.input_started and self.next_index == 1 then
		self.time, self.motion_time = time, time
	end
	while self.next_index <= #self.chart.objects do
		local i = self.next_index
		local object = self.chart.objects[i]
		if object.time >= time then break end
		self:moveTo(object.time)
		local hit = math.abs(object.x - self.x) <= self.half_width + 1e-7
		self.states[i] = hit and "hit" or "miss"
		self.events[#self.events + 1] = {index = i, time = object.time, hit = hit, x = self.x}
		if object.kind == "banana" or object.kind == "tiny" then
			if hit then self.bonus_hits = self.bonus_hits + 1 else self.bonus_misses = self.bonus_misses + 1 end
		else
			if hit then self.hits = self.hits + 1 else self.misses = self.misses + 1 end
		end
		local target_index = self.hyper_targets[i]
		if hit and target_index then
			local target = self.chart.objects[target_index]
			self.motion_x, self.motion_time = self.x, self.time
			self.hyper_until = target.time
			self.hyper_speed = math.max(self.dash_speed, math.abs(target.x - self.x) / math.max(0.001, target.time - object.time))
		end
		self.next_index = i + 1
	end
	self:moveTo(time)
end

---@param event rizu.VirtualInputEvent
---@param time number
---@param paused boolean?
function Rules:receive(event, time, paused)
	self:update(time)
	self.input_started = true
	self.motion_x, self.motion_time = self.x, self.time
	if event.value ~= nil then self.buttons[event.id] = event.value == true end
end

---@param chart chart.osu.CatchChart
---@return rizu.ReplayFrame[]
function Rules.autoplay(chart)
	local rules = Rules(chart)
	---@type rizu.ReplayFrame[]
	local frames = {}
	---@param time number
	---@param id integer
	---@param pressed boolean
	local function add(time, id, pressed)
		local event = VirtualInputEvent(id, pressed, 1)
		frames[#frames + 1] = {time = time, event = event}
		rules:receive(event, time)
	end
	add(rules.time, 3, true)
	for _, object in ipairs(chart.objects) do
		if object.time >= rules.time then
			local start = rules.time
			local direction = object.x > rules.x and 2 or 1
			local speed = rules:speed()
			local arrival = start + math.abs(object.x - rules.x) / speed
			local stop = math.min(arrival, object.time)
			add(start, direction, true)
			add(stop, direction, false)
			-- Equal-time objects share one position; never emit a frame in the past.
			rules:update(object.time + 1e-8)
		end
	end
	return frames
end

return Rules
