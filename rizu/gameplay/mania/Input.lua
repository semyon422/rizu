local class = require("class")
local InputBinder = require("rizu.input.InputBinder")
local KeyPhysicInputEvent = require("rizu.input.KeyPhysicInputEvent")

---@class rizu.gameplay.mania.Input
---@operator call: rizu.gameplay.mania.Input
local Input = class()

---@param config table
---@param input_mode string
function Input:new(config, input_mode)
	self.binder = InputBinder(config, input_mode)
end

---@param event table
---@return rizu.VirtualInputEvent?
function Input:transform(event)
	local physic_event = KeyPhysicInputEvent.fromInputChangedEvent(event)
	return physic_event and self.binder:transform(physic_event)
end

return Input
