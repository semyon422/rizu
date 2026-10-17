local PhysicInputEvent = require("rizu.input.PhysicInputEvent")
local InputDevice = require("rizu.input.InputDevice")

---@class rizu.KeyPhysicInputEvent: rizu.PhysicInputEvent
---@operator call: rizu.KeyPhysicInputEvent
local KeyPhysicInputEvent = PhysicInputEvent + {}

---@param device rizu.InputDevice
---@param key string
---@param state boolean true - pressed, false - released
function KeyPhysicInputEvent:new(device, key, state)
	self.device = device
	self.key = key
	self.state = state
end

---@param event {[any]: any}
---@return rizu.KeyPhysicInputEvent?
function KeyPhysicInputEvent.fromInputChangedEvent(event)
	if event.name ~= "inputchanged" then
		return
	end

	local d_type, d_id, key, state = event[1], event[2], event[3], event[4]

	return KeyPhysicInputEvent(InputDevice(d_type, d_id), key, state)
end

return KeyPhysicInputEvent
