local class = require("class")
local asynckey = require("asynckey")
local just = require("just")
local MidiInputFactory = require("native.midi.MidiInputFactory")

---@alias rizu.LoopEventValue string|number|boolean|table|userdata
---@alias rizu.LoopCallback fun(...: rizu.LoopEventValue): boolean?
---@alias rizu.LoveEventIterator fun(): string?, rizu.LoopEventValue?, rizu.LoopEventValue?, rizu.LoopEventValue?, rizu.LoopEventValue?, rizu.LoopEventValue?, rizu.LoopEventValue?
---@alias rizu.MidiEventIterator fun(state: native.IMidiInput, port?: integer): integer?, number?, boolean?

---@class rizu.LoopEvent
---@field name string?
---@field time number?
---@field [integer] rizu.LoopEventValue?

---@class rizu.LoopEvents
---@operator call: rizu.LoopEvents
local LoopEvents = class()

---@param loop rizu.Loop
function LoopEvents:new(loop)
	---@type rizu.Loop
	self.loop = loop
	self.asynckey = false
	self.event_time = 0

	local midi_input_factory = MidiInputFactory()
	self.midi_input = midi_input_factory:getMidiInput()

	---@type rizu.LoopEvent
	self.event_table = {}
	---@type rizu.LoopEvent
	self.re = {}
end

---@param time number
---@return number
function LoopEvents:clampEventTime(time)
	return math.min(math.max(time, self.loop.prev_time), self.loop.time)
end

---@param name string
---@param ... rizu.LoopEventValue
---@return string? device
---@return integer? id
---@return string|number? key
---@return boolean? state
function LoopEvents:transformInputEvent(name, ...)
	if name == "keypressed" then
		return "keyboard", 1, select(2, ...), true
	elseif name == "keyreleased" then
		return "keyboard", 1, select(2, ...), false
	elseif name == "gamepadpressed" then
		return "gamepad", select(1, ...):getID(), select(2, ...), true
	elseif name == "gamepadreleased" then
		return "gamepad", select(1, ...):getID(), select(2, ...), false
	elseif name == "joystickpressed" then
		return "joystick", select(1, ...):getID(), select(2, ...), true
	elseif name == "joystickreleased" then
		return "joystick", select(1, ...):getID(), select(2, ...), false
	elseif name == "midipressed" then
		return "midi", 1, select(1, ...), true
	elseif name == "midireleased" then
		return "midi", 1, select(1, ...), false
	end
end

---@param device string?
---@param id integer?
---@param key string|number?
---@param state boolean?
function LoopEvents:resendTransformed(device, id, key, state)
	if not device then return end
	local name = "inputchanged"
	local icb = just.callbacks[name] --[[@as rizu.LoopCallback?]]
	if icb and icb(device, id, key, state) then return end
	local re = self.re
	re[1], re[2], re[3], re[4] = device, id, key, state
	re.name = name
	re.time = self:clampEventTime(self.event_time)
	return self.loop:send(re)
end

---@param name string
---@param a? rizu.LoopEventValue
---@param b? rizu.LoopEventValue
---@param c? rizu.LoopEventValue
---@param d? rizu.LoopEventValue
---@param e? rizu.LoopEventValue
---@param f? rizu.LoopEventValue
function LoopEvents:dispatchEvent(name, a, b, c, d, e, f)
	self:resendTransformed(self:transformInputEvent(name, a, b, c, d, e, f))
	local icb = just.callbacks[name] --[[@as rizu.LoopCallback?]]
	if icb and icb(a, b, c, d, e, f) then return end
	local et = self.event_table
	et.name = name
	et.time = self:clampEventTime(self.event_time)
	et[1], et[2], et[3], et[4], et[5], et[6] = a, b, c, d, e, f
	self.loop:send(et)
end

---@param time number
---@return number|string?
function LoopEvents:pollEvents(time)
	love.event.pump()

	local asynckey_working = self.asynckey and asynckey.events
	if asynckey_working then
		if love.window.hasFocus() then
			for event in asynckey.events do
				self.event_time = event.time
				if event.state then
					self:dispatchEvent("keypressed", event.key, event.key)
				else
					self:dispatchEvent("keyreleased", event.key, event.key)
				end
			end
		else
			asynckey.clear()
		end
	end

	local poll_events = love.event.poll --[[@as fun(): rizu.LoveEventIterator]]
	for name, a, b, c, d, e, f in poll_events() do
		self.event_time = time
		if name == "quit" then
			self.loop.quit_code = a or 0
			if not love.quit or not love.quit() then
				self.loop.quitting = true
				return a or 0
			end
		end
		if not asynckey_working or name ~= "keypressed" and name ~= "keyreleased" then
			self:dispatchEvent(name, a, b, c, d, e, f)
		end
	end

	local midi_events, midi_state = self.midi_input:events()
	for port, note, status in midi_events --[[@as rizu.MidiEventIterator]], midi_state do
		self.event_time = time
		if status then
			self:dispatchEvent("midipressed", note)
		else
			self:dispatchEvent("midireleased", note)
		end
	end
end

return LoopEvents
