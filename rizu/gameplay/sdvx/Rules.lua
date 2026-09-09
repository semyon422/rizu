local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local class = require("class")
local ButtonRules = require("rizu.gameplay.sdvx.ButtonRules")
local Laser = require("rizu.gameplay.sdvx.Laser")

---@class rizu.sdvx.Rules
---@operator call: rizu.sdvx.Rules
---@field lasers rizu.sdvx.Laser[]
---@field buttons {[integer]: boolean}
local Rules = class()
Rules.window = 0.1
Rules.preempt = 1.5
Rules.hits = 0
Rules.misses = 0

---@param chart chart.ksm.SdvxChart
function Rules:new(chart)
	self.chart = chart
	self.button_rules = ButtonRules(chart.buttons)
	self.lasers, self.buttons = {}, {}
	local samples = 0
	for _, chain in ipairs(chart.lasers) do
		local first, last = chain.segments[1], chain.segments[#chain.segments]
		samples = samples + math.ceil((last.end_time - first.time) / Laser.step) + 1
		assert(samples <= 2000000, "SDVX prototype: laser simulation budget exceeded.")
		self.lasers[#self.lasers + 1] = Laser(chain)
	end
end

---@param time number
function Rules:update(time)
	self.button_rules:update(time)
	for _, laser in ipairs(self.lasers) do laser:update(time) end
	self.hits, self.misses = self.button_rules.hits, self.button_rules.misses
end

---@param lane integer
---@return integer
function Rules:direction(lane)
	local first = 7 + (lane - 1) * 2
	return (self.buttons[first + 1] and 1 or 0) - (self.buttons[first] and 1 or 0)
end

---@param event rizu.VirtualInputEvent
---@param time number
---@param paused boolean?
function Rules:receive(event, time, paused)
	local id = event.id
	assert(id >= 1 and id <= 12 and id == math.floor(id), "Invalid SDVX input ID.")
	assert(event.column == 1 or event.column == 2, "Invalid SDVX input column.")
	paused = paused or event.column == 2
	if id <= 10 then
		assert(type(event.value) == "boolean" and not event.pos, "Invalid SDVX key event.")
		if id <= 6 then
			self.button_rules:receive(id, event.value, time, paused)
			return
		end
		local lane = id <= 8 and 1 or 2
		local previous = self:direction(lane)
		self.buttons[id] = event.value
		local direction = self:direction(lane)
		for _, laser in ipairs(self.lasers) do
			if laser.chain.lane == lane then
				laser:setDirection(direction, time)
				if direction ~= previous and direction ~= 0 then
					-- The edge is a turn, not a cursor teleport. Held movement uses the grid.
					laser:turn(direction * 1e-6, time, paused)
				end
			end
		end
	else
		assert(event.value == nil and event.pos and event.pos[2] == 0, "Invalid SDVX relative turn.")
		local delta = event.pos[1]
		assert(delta == delta and math.abs(delta) < math.huge, "Invalid SDVX relative displacement.")
		for _, laser in ipairs(self.lasers) do
			if laser.chain.lane == id - 10 then laser:turn(delta, time, paused) end
		end
	end
end

---@param chart chart.ksm.SdvxChart
---@return rizu.ReplayFrame[]
function Rules.autoplay(chart)
	---@type {time: number, id: integer, pressed: boolean, order: integer}[]
	local actions = {}
	---@param time number
	---@param id integer
	---@param pressed boolean
	local function add(time, id, pressed)
		assert(#actions < 400000, "SDVX prototype: autoplay action budget exceeded.")
		actions[#actions + 1] = {time = time, id = id, pressed = pressed, order = #actions + 1}
	end
	for _, object in ipairs(chart.buttons) do
		add(object.time, object.lane, true)
		add(object.end_time, object.lane, false)
	end
	for _, chain in ipairs(chart.lasers) do
		---@type integer?
		local held
		for _, segment in ipairs(chain.segments) do
			local direction = segment.to > segment.from and 1 or segment.to < segment.from and -1 or 0
			local id = direction ~= 0 and (7 + (chain.lane - 1) * 2 + (direction == 1 and 1 or 0)) or nil
			if held and (held ~= id or segment.slam) then add(segment.time, held, false) end
			if id and (held ~= id or segment.slam) then add(segment.time, id, true) end
			held = id
		end
		if held then add(chain.segments[#chain.segments].end_time, held, false) end
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
