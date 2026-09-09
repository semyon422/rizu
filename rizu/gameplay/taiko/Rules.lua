local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.taiko.State
---@field result "hit"|"miss"|"single"|"double"?
---@field count integer
---@field first_time number?
---@field first_id integer?
---@field last_color string?

---@class rizu.taiko.Judgement
---@field index integer
---@field time number
---@field result string

---@class rizu.taiko.Rules
---@operator call: rizu.taiko.Rules
---@field chart chart.osu.TaikoChart
---@field states rizu.taiko.State[]
---@field buttons {[integer]: boolean}
---@field events rizu.taiko.Judgement[]
---@field sounds integer[] Object indices, one per successful action.
local Rules = class()
Rules.second_window = 0.03
Rules.preempt = 1.5

---@param chart chart.osu.TaikoChart
function Rules:new(chart)
	self.chart = chart
	self.window = (120 - 8 * chart.overall_difficulty) / 1000
	self.buttons, self.states, self.events, self.sounds = {}, {}, {}, {}
	self.hits, self.misses, self.doubles, self.singles = 0, 0, 0, 0
	self.first_index = 1
	for i in ipairs(chart.objects) do self.states[i] = {count = 0} end
end

---@param index integer
---@param time number
---@param result "hit"|"miss"|"single"|"double"
function Rules:finish(index, time, result)
	local state = self.states[index]
	assert(not state.result)
	state.result = result
	self.events[#self.events + 1] = {index = index, time = time, result = result}
	if result == "miss" then self.misses = self.misses + 1 else self.hits = self.hits + 1 end
	if result == "single" then self.singles = self.singles + 1 end
	if result == "double" then self.doubles = self.doubles + 1 end
end

---@param time number
function Rules:update(time)
	-- Resolve deadlines chronologically, not according to source interval lengths.
	while true do
		---@type integer?
		local due
		local deadline = math.huge
		for i = self.first_index, #self.chart.objects do
			local object, state = self.chart.objects[i], self.states[i]
			if object.time > time + self.window then break end
			if not state.result then
				local ending = object.kind == "note" and (state.first_time and state.first_time + self.second_window or object.time + self.window) or object.end_time
				if ending < time and ending < deadline then due, deadline = i, ending end
			end
		end
		if not due then break end
		local state = self.states[due]
		self:finish(due, deadline, state.first_time and "single" or "miss")
	end
	while self.states[self.first_index] and self.states[self.first_index].result do
		self.first_index = self.first_index + 1
	end
end

---@param id integer
---@return "don"|"kat"
local function color(id)
	return id <= 2 and "don" or "kat"
end

---@param event rizu.VirtualInputEvent
---@param time number
---@param paused boolean?
function Rules:receive(event, time, paused)
	self:update(time)
	assert(event.id >= 1 and event.id <= 4 and type(event.value) == "boolean", "Invalid Taiko action.")
	local held = self.buttons[event.id]
	self.buttons[event.id] = event.value
	if paused or event.column == 2 or not event.value or held then return end
	local hit_color = color(event.id)
	-- Pending second hands take priority, followed by ordinary notes, then intervals.
	for i = self.first_index, #self.chart.objects do
		local object, state = self.chart.objects[i], self.states[i]
		if object.time > time + self.window then break end
		if not state.result and state.first_time and time >= state.first_time and time <= state.first_time + self.second_window
			and object.color == hit_color and event.id ~= state.first_id and self.buttons[state.first_id] then
			self.sounds[#self.sounds + 1] = i
			self:finish(i, time, "double")
			return
		end
	end
	for i = self.first_index, #self.chart.objects do
		local object, state = self.chart.objects[i], self.states[i]
		if object.time > time + self.window then break end
		if object.kind == "note" and not state.result and not state.first_time and math.abs(time - object.time) <= self.window then
			if object.color ~= hit_color then
				self:finish(i, time, "miss")
			elseif object.big then
				state.first_time, state.first_id = time, event.id
				self.sounds[#self.sounds + 1] = i
			else
				self.sounds[#self.sounds + 1] = i
				self:finish(i, time, "hit")
			end
			return
		end
	end
	for i = self.first_index, #self.chart.objects do
		local object, state = self.chart.objects[i], self.states[i]
		if object.time > time then break end
		if object.kind ~= "note" and not state.result and time <= object.end_time then
			if object.kind == "spinner" and state.last_color == hit_color then return end
			state.last_color, state.count = hit_color, state.count + 1
			self.sounds[#self.sounds + 1] = i
			if state.count >= object.target then self:finish(i, time, "hit") end
			return
		end
	end
end

---@param chart chart.osu.TaikoChart
---@return rizu.ReplayFrame[]
function Rules.autoplay(chart)
	---@type {time: number, id: integer, pressed: boolean, order: integer}[]
	local actions = {}
	---@param time number
	---@param id integer
	---@param pressed boolean
	local function add(time, id, pressed)
		actions[#actions + 1] = {time = time, id = id, pressed = pressed, order = #actions + 1}
	end
	for _, object in ipairs(chart.objects) do
		if object.kind == "note" then
			local id = object.color == "don" and 1 or 3
			add(object.time, id, true)
			if object.big then add(object.time, id + 1, true) end
			add(object.time, id, false)
			if object.big then add(object.time, id + 1, false) end
		else
			for j = 1, object.target do
				local time = object.time + (object.end_time - object.time) * (j - 0.5) / object.target
				local id = j % 2 == 1 and 1 or 3
				add(time, id, true); add(time, id, false)
			end
		end
	end
	table.sort(actions, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.order < b.order
	end)
	---@type rizu.ReplayFrame[]
	local frames = {}
	for _, action in ipairs(actions) do
		frames[#frames + 1] = {time = action.time, event = VirtualInputEvent(action.id, action.pressed, 1)}
	end
	return frames
end

return Rules
