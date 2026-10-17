local ReplayPlayer = require("rizu.engine.replay.ReplayPlayer")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

---@param t testing.T
function test.all(t)
	---@type rizu.ReplayFrame[]
	local events = {
		{time = 0, event = VirtualInputEvent(0)},
		{time = 1, event = VirtualInputEvent(1)},
		{time = 2, event = VirtualInputEvent(3)},
		{time = 4, event = VirtualInputEvent(4)},
	}

	local p = ReplayPlayer(events)

	t:tdeq({p:play(-1)}, {})
	t:tdeq({p:play(1)}, {events[1]})
	t:tdeq({p:play(1)}, {events[2]})
	t:tdeq({p:play(1)}, {})
	t:tdeq({p:play(10)}, {events[3]})
	t:tdeq({p:play(10)}, {events[4]})
	t:tdeq({p:play(10)}, {})
end

return test
