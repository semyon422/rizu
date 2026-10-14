local Events = require("rizu.api.Events")
local InputBinder = require("rizu.input.InputBinder")
local InputDevice = require("rizu.input.InputDevice")

---`rizu.api.Input` that remembers the keys and saves nothing. The selected chart is always 4K.
---@class rizu.api.fake.FakeInput : rizu.api.Events
---@operator call: rizu.api.fake.FakeInput
local FakeInput = Events + {}

function FakeInput:new()
	Events.new(self)
	self.config = {}
end

function FakeInput:getInputMode() return "4key" end
function FakeInput:getColumns(input_mode) return InputBinder(self.config, input_mode).columns end
function FakeInput:getSlotCount(column) return column:match("^scratch%d+$") and 2 or 1 end

function FakeInput:getBinding(input_mode, column, slot)
	return InputBinder(self.config, input_mode):getKey(column, slot)
end

function FakeInput:setBinding(input_mode, column, slot, key, device_type, device_id)
	InputBinder(self.config, input_mode):setKey(column, slot, key, InputDevice(device_type, device_id))
	self:emit("bindings_changed", input_mode)
end

function FakeInput:clearBinding(input_mode, column, slot)
	InputBinder(self.config, input_mode):setKey(column, slot)
	self:emit("bindings_changed", input_mode)
end

function FakeInput:resetBindings(input_mode)
	InputBinder(self.config, input_mode):reset()
	self:emit("bindings_changed", input_mode)
end

return FakeInput
