local class = require("class")
local asynckey = require("asynckey")
local just = require("just")
local MidiInputFactory = require("native.midi.MidiInputFactory")

---@class rizu.LoopEvents
---@operator call: rizu.LoopEvents
local LoopEvents = class()

function LoopEvents:new(loop)
	---@type rizu.Loop
	self.loop = loop
	self.asynckey = false
	self.event_time = 0

	local midi_input_factory = MidiInputFactory()
	self.midi_input = midi_input_factory:getMidiInput()

	self.event_table = {}
	self.re = {}
end

---@param time number
---@return number
function LoopEvents:clampEventTime(time)
	return math.min(math.max(time, self.loop.prev_time), self.loop.time)
end

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

function LoopEvents:resendTransformed(...)
	if not ... then return end
	local name = "inputchanged"
	local icb = just.callbacks[name]
	if icb and icb(...) then return end
	local re = self.re
	re[1], re[2], re[3], re[4], re[5], re[6] = ...
	re.name = name
	re.time = self:clampEventTime(self.event_time)
	return self.loop:send(re)
end

function LoopEvents:dispatchEvent(name, a, b, c, d, e, f)
	self:resendTransformed(self:transformInputEvent(name, a, b, c, d, e, f))
	local icb = just.callbacks[name]
	if icb and icb(a, b, c, d, e, f) then return end
	local et = self.event_table
	et.name = name
	et.time = self:clampEventTime(self.event_time)
	et[1], et[2], et[3], et[4], et[5], et[6] = a, b, c, d, e, f
	self.loop:send(et)
end

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

	for name, a, b, c, d, e, f in love.event.poll() do
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

	for port, note, status in self.midi_input:events() do
		self.event_time = time
		if status then
			self:dispatchEvent("midipressed", note)
		else
			self:dispatchEvent("midireleased", note)
		end
	end
end

return LoopEvents
