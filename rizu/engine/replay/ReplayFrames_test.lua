local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

---@param t testing.T
function test.all(t)
	---@type rizu.ReplayFrame[]
	local events = {
		{time = 0, event = VirtualInputEvent(1, false, 1)},
		{time = 1, event = VirtualInputEvent(2, true, nil, {1, 2})},
		{time = math.pi, event = VirtualInputEvent(2, "left", 2, {math.pi, 0})},
		{time = 2, event = VirtualInputEvent(2)},
	}

	local s = ReplayFrames.encode(events)
	local _events = ReplayFrames.decode(s)

	t:tdeq(_events, events)
end

return test
