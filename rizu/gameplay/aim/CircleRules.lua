local class = require("class")
local AimChart = require("chart.format.osu.AimChart")
local Sliders = require("rizu.gameplay.aim.Sliders")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.aim.Judgement
---@field index integer
---@field time number
---@field hit boolean
---@field delta number

---@class rizu.aim.CheckpointJudgement: rizu.aim.Judgement
---@field kind "tick"|"repeat"|"tail"
---@field x number
---@field y number

---@class rizu.aim.ScheduledEvent
---@field index integer
---@field time number
---@field priority integer
---@field checkpoint chart.osu.SliderCheckpoint?
---@field finish boolean?

---@class rizu.aim.CircleRules
---@operator call: rizu.aim.CircleRules
---@field chart chart.osu.AimChart
---@field states ("hit"|"miss")[]
---@field heads ("hit"|"miss")[]
---@field events rizu.aim.Judgement[]
---@field checkpoint_events rizu.aim.CheckpointJudgement[]
---@field buttons {[integer]: boolean}
---@field scheduled rizu.aim.ScheduledEvent[]
---@field sliders {[integer]: rizu.aim.Slider}
local CircleRules = class()

---@param chart chart.osu.AimChart
function CircleRules:new(chart)
	assert(AimChart.isSupported(chart))
	self.chart = chart
	self.radius = 54.4 - 4.48 * chart.circle_size
	local ar = chart.approach_rate
	self.preempt = ar < 5 and 1.8 - 0.12 * ar or 1.2 - 0.15 * (ar - 5)
	self.window = (200 - 10 * chart.overall_difficulty) / 1000
	self.states, self.heads = {}, {}
	self.events, self.checkpoint_events = {}, {}
	self.buttons = {}
	self.x, self.y = 256, 192
	self.next_index = 1
	self.hits, self.misses = 0, 0
	self.checkpoint_hits, self.checkpoint_misses = 0, 0
	self.sliders = Sliders.prepare(chart)
	self.scheduled, self.schedule_index = {}, 1
	for i, object in ipairs(chart.objects) do
		local deadline = object.time + self.window
		self.scheduled[#self.scheduled + 1] = {index = i, time = deadline, priority = 1}
		local slider = self.sliders[i]
		if slider then
			for _, checkpoint in ipairs(slider.timing.checkpoints) do
				self.scheduled[#self.scheduled + 1] = {index = i, time = checkpoint.time, checkpoint = checkpoint, priority = 2}
			end
			self.scheduled[#self.scheduled + 1] = {index = i, time = math.max(deadline, slider.timing.end_time), finish = true, priority = 3}
		end
	end
	table.sort(self.scheduled, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		if a.priority ~= b.priority then return a.priority < b.priority end
		return a.index < b.index
	end)
end

---@param index integer
---@param time number
---@param hit boolean
function CircleRules:judge(index, time, hit)
	self.states[index] = hit and "hit" or "miss"
	self.events[#self.events + 1] = {index = index, time = time, hit = hit, delta = time - self.chart.objects[index].time}
	if hit then self.hits = self.hits + 1 else self.misses = self.misses + 1 end
end

function CircleRules:advanceHead()
	while self.heads[self.next_index] do self.next_index = self.next_index + 1 end
end

---@param index integer
---@param time number
---@param hit boolean
function CircleRules:judgeHead(index, time, hit)
	self.heads[index] = hit and "hit" or "miss"
	local slider = self.sliders[index]
	if slider then
		slider.intact = slider.intact and hit
	else
		self:judge(index, time, hit)
	end
	self:advanceHead()
end

---@param x number
---@param y number
---@param radius number
---@return boolean
function CircleRules:inside(x, y, radius)
	return (self.x - x) ^ 2 + (self.y - y) ^ 2 <= radius ^ 2
end

---@return boolean
function CircleRules:isHeld()
	for _, pressed in pairs(self.buttons) do
		if pressed then return true end
	end
	return false
end

---@param time number
function CircleRules:update(time)
	-- Strict expiry gives all events at the checkpoint timestamp the same ordering,
	-- whether delivered by the UI or ReplayPlayer's pre-input engine updates.
	while self.schedule_index <= #self.scheduled do
		local scheduled = self.scheduled[self.schedule_index]
		if scheduled.time >= time then break end
		self.schedule_index = self.schedule_index + 1
		local i = scheduled.index
		local slider = self.sliders[i]
		local checkpoint = scheduled.checkpoint
		if checkpoint then
			local x, y = slider.path:position(checkpoint.progress)
			local hit = self:isHeld() and self:inside(x, y, self.radius * 2.4)
			slider.intact = slider.intact and hit
			self.checkpoint_events[#self.checkpoint_events + 1] = {
				index = i, time = scheduled.time, hit = hit, delta = 0,
				kind = checkpoint.kind, x = x, y = y,
			}
			if hit then self.checkpoint_hits = self.checkpoint_hits + 1
			else self.checkpoint_misses = self.checkpoint_misses + 1 end
		elseif scheduled.finish then
			self:judge(i, scheduled.time, slider.intact)
		elseif not self.heads[i] then
			self:judgeHead(i, scheduled.time, false)
		end
	end
end

---@param event rizu.VirtualInputEvent
---@param time number
---@param paused boolean?
---@return integer? hit_index
function CircleRules:receive(event, time, paused)
	self:update(time)
	if event.pos then self.x, self.y = event.pos[1], event.pos[2] end
	if event.value == nil then return end
	local was_pressed = self.buttons[event.id]
	self.buttons[event.id] = event.value == true
	if paused or event.column == 2 or event.value ~= true or was_pressed then return end
	-- Note lock concerns heads, not already-started slider bodies.
	local i = self.next_index
	local object = self.chart.objects[i]
	if not object or time < object.time - self.preempt or math.abs(time - object.time) > self.window then return end
	if not self:inside(object.x, object.y, self.radius) then return end
	self:judgeHead(i, time, true)
	return i
end

---@param chart chart.osu.AimChart
---@return rizu.ReplayFrame[]
function CircleRules.autoplay(chart)
	local sliders = Sliders.prepare(chart)
	---@type {time: number, event: rizu.VirtualInputEvent, order: integer}[]
	local frames = {}
	---@param time number
	---@param event rizu.VirtualInputEvent
	local function add(time, event)
		assert(#frames < 2000000, "Aim prototype: autoplay frame budget exceeded.")
		frames[#frames + 1] = {time = time, event = event, order = #frames + 1}
	end
	for i, object in ipairs(chart.objects) do
		-- An alternating head key avoids suppressing a fresh press while a slider is held.
		local id = (i - 1) % 2 + 1
		add(object.time, VirtualInputEvent(id, true, 1, {object.x, object.y}))
		local slider = sliders[i]
		if slider then
			local timing = slider.timing
			local count = math.ceil((timing.end_time - object.time) * 120)
			assert(count < 2000000, "Aim prototype: autoplay duration budget exceeded.")
			for sample = 1, count - 1 do
				local time = object.time + sample / 120
				local x, y = slider.path:position(timing:progress(time))
				add(time, VirtualInputEvent(0, nil, 1, {x, y}))
			end
			for _, checkpoint in ipairs(timing.checkpoints) do
				local x, y = slider.path:position(checkpoint.progress)
				add(checkpoint.time, VirtualInputEvent(0, nil, 1, {x, y}))
			end
			add(timing.end_time + 1e-7, VirtualInputEvent(id, false, 1))
		else
			add(object.time, VirtualInputEvent(id, false, 1))
		end
	end
	table.sort(frames, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.order < b.order
	end)
	return frames
end

return CircleRules
