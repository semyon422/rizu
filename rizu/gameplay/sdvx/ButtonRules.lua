local class = require("class")

---@class rizu.sdvx.ButtonState
---@field head boolean?
---@field failed boolean
---@field result "hit"|"miss"?

---@class rizu.sdvx.ButtonJudgement
---@field index integer
---@field time number
---@field result "hit"|"miss"

---@class rizu.sdvx.ButtonRules
---@operator call: rizu.sdvx.ButtonRules
---@field objects chart.ksm.SdvxButton[]
---@field states rizu.sdvx.ButtonState[]
---@field buttons {[integer]: boolean}
---@field events rizu.sdvx.ButtonJudgement[]
local ButtonRules = class()
ButtonRules.window = 0.1

---@param objects chart.ksm.SdvxButton[]
function ButtonRules:new(objects)
	self.objects = objects
	self.states, self.buttons, self.events = {}, {}, {}
	self.first_index, self.hits, self.misses = 1, 0, 0
	for i in ipairs(objects) do self.states[i] = {failed = false} end
end

---@param index integer
---@param time number
---@param hit boolean
function ButtonRules:finish(index, time, hit)
	local state = self.states[index]
	assert(not state.result)
	state.result = hit and "hit" or "miss"
	self.events[#self.events + 1] = {index = index, time = time, result = state.result}
	if hit then self.hits = self.hits + 1 else self.misses = self.misses + 1 end
end

---@param time number
function ButtonRules:update(time)
	while true do
		---@type integer?
		local due
		local deadline = math.huge
		for i = self.first_index, #self.objects do
			local object, state = self.objects[i], self.states[i]
			if object.time > time + self.window then break end
			if not state.result then
				local ending = state.head and object.end_time or object.time + self.window
				if ending < time and ending < deadline then due, deadline = i, ending end
			end
		end
		if not due then break end
		local object, state = self.objects[due], self.states[due]
		self:finish(due, deadline, not not (state.head and not state.failed and self.buttons[object.lane]))
	end
	while self.states[self.first_index] and self.states[self.first_index].result do self.first_index = self.first_index + 1 end
end

---@param lane integer
---@param pressed boolean
---@param time number
---@param paused boolean?
function ButtonRules:receive(lane, pressed, time, paused)
	assert(lane >= 1 and lane <= 6 and lane == math.floor(lane))
	self:update(time)
	local held = self.buttons[lane]
	self.buttons[lane] = pressed
	-- Releases during pause are still releases: do not resurrect a broken hold on replay.
	if not pressed then
		for i = self.first_index, #self.objects do
			local object, state = self.objects[i], self.states[i]
			if object.time > time + self.window then break end
			if object.lane == lane and state.head and not state.result then
				if time >= object.end_time then self:finish(i, object.end_time, not state.failed)
				else state.failed = true end
			end
		end
		return
	end
	if paused or held then return end
	for i = self.first_index, #self.objects do
		local object, state = self.objects[i], self.states[i]
		if object.time > time + self.window then break end
		if object.lane == lane and not state.result and not state.head and math.abs(time - object.time) <= self.window then
			state.head = true
			if object.kind == "chip" then self:finish(i, time, true) end
			return
		end
	end
end

return ButtonRules
