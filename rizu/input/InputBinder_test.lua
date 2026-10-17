local InputBinder = require("rizu.input.InputBinder")
local InputDevice = require("rizu.input.InputDevice")
local KeyPhysicInputEvent = require("rizu.input.KeyPhysicInputEvent")

local test = {}

---@param t testing.T
function test.all(t)
	local config = {}
	local binder = InputBinder(config, "4key")
	local device = InputDevice("keyboard", 1)

	local event = binder:transform(KeyPhysicInputEvent(device, "d", true))
	t:assert(not event)

	binder:setKey("key1", 1, "d", device)
	t:assert(binder:getKey("key1", 1))
	t:assert(not binder:getKey("key1", 2))

	event = binder:transform(KeyPhysicInputEvent(device, "d", true))
	t:tdeq(event, {column = 1, value = true, id = 1})

	binder:setKey("key1", 1)

	event = binder:transform(KeyPhysicInputEvent(device, "d", true))
	t:assert(not event)
end

return test
