local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local Knob = require("rizu.gameplay.sdvx.Knob")

---@class rizu.sdvx.Input
---@operator call: rizu.sdvx.Input
---@field knobs rizu.sdvx.Knob[]
local Input = class()
---@type {[string]: integer}
local keys = {d = 1, f = 2, j = 3, k = 4, c = 5, m = 6, w = 7, e = 8, o = 9, p = 10}

function Input:new()
	self.knobs = {Knob(1, false, 0), Knob(1, false, 0)}
end

---@param event {name: string, [integer]: any}
---@return rizu.VirtualInputEvent?
function Input:transform(event)
	if event.name ~= "keypressed" and event.name ~= "keyreleased" then return end
	local id = keys[event[2] or event[1]] -- Prefer scancode when provided by LÖVE.
	if not id then return end
	return VirtualInputEvent(id, event.name == "keypressed", 1)
end

-- Called by a configured hardware adapter, not by polling arbitrary joystick axes.
---@param lane integer
---@param value number
---@param paused boolean?
---@return rizu.VirtualInputEvent
function Input:axis(lane, value, paused)
	assert(lane == 1 or lane == 2)
	local delta = self.knobs[lane]:sample(value, paused)
	return VirtualInputEvent(10 + lane, nil, paused and 2 or 1, {delta, 0})
end

return Input
