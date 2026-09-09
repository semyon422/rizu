local class = require("class")
local AimChart = require("chart.format.osu.AimChart")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.aim.Judgement
---@field index integer
---@field time number
---@field hit boolean
---@field delta number

---@class rizu.aim.CircleRules
---@operator call: rizu.aim.CircleRules
---@field chart chart.osu.AimChart
---@field states ("hit"|"miss")[]
---@field events rizu.aim.Judgement[]
---@field buttons {[integer]: boolean}
local CircleRules = class()

---@param chart chart.osu.AimChart
function CircleRules:new(chart)
	assert(AimChart.isSupported(chart))
	self.chart = chart
	self.radius = 54.4 - 4.48 * chart.circle_size
	local ar = chart.approach_rate
	self.preempt = ar < 5 and 1.8 - 0.12 * ar or 1.2 - 0.15 * (ar - 5)
	self.window = (200 - 10 * chart.overall_difficulty) / 1000
	self.states = {}
	self.events = {}
	self.buttons = {}
	self.x, self.y = 256, 192
	self.next_index = 1
	self.hits, self.misses = 0, 0
end

---@param index integer
---@param time number
---@param hit boolean
function CircleRules:judge(index, time, hit)
	self.states[index] = hit and "hit" or "miss"
	self.events[#self.events + 1] = {index = index, time = time, hit = hit, delta = time - self.chart.objects[index].time}
	if hit then
		self.hits = self.hits + 1
	else
		self.misses = self.misses + 1
	end
end

---@param time number
function CircleRules:update(time)
	local objects = self.chart.objects
	while self.next_index <= #objects do
		local i = self.next_index
		if not self.states[i] then
			local deadline = objects[i].time + self.window
			if time <= deadline then
				break
			end
			self:judge(i, deadline, false)
		end
		self.next_index = i + 1
	end
end

---@param event rizu.VirtualInputEvent
---@param time number
---@param paused boolean?
---@return integer? hit_index
function CircleRules:receive(event, time, paused)
	self:update(time)
	if event.pos then
		self.x, self.y = event.pos[1], event.pos[2]
	end
	if event.value == nil then
		return
	end
	local was_pressed = self.buttons[event.id]
	self.buttons[event.id] = event.value == true
	if paused or event.column == 2 or event.value ~= true or was_pressed then
		return
	end
	-- Only the earliest unresolved circle may consume a press (including ties).
	local i = self.next_index
	local object = self.chart.objects[i]
	if not object or time < object.time - self.preempt or math.abs(time - object.time) > self.window then
		return
	end
	local dx, dy = self.x - object.x, self.y - object.y
	if dx * dx + dy * dy > self.radius * self.radius then
		return
	end
	self:judge(i, time, true)
	self:update(time)
	return i
end

---@param chart chart.osu.AimChart
---@return rizu.ReplayFrame[]
function CircleRules.autoplay(chart)
	---@type rizu.ReplayFrame[]
	local frames = {}
	for _, object in ipairs(chart.objects) do
		frames[#frames + 1] = {time = object.time, event = VirtualInputEvent(1, true, 1, {object.x, object.y})}
		frames[#frames + 1] = {time = object.time, event = VirtualInputEvent(1, false, 1)}
	end
	return frames
end

return CircleRules
