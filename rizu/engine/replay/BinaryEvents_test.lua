local BinaryEvents = require("rizu.engine.replay.BinaryEvents")

local test = {}

---@param t testing.T
function test.all(t)
	---@type rizu.BinaryEvent[]
	local events = {
		{time = 0, id = 1, value = false, column = 1},
		{time = 1, id = 2, value = true, pos = {1, 2}},
		{time = math.pi, id = 2, value = "left", column = 2, pos = {math.pi, 0}},
		{time = 2, id = 3},
	}

	local s = BinaryEvents.encode(events)
	local _events = BinaryEvents.decode(s)

	t:tdeq(_events, events)
end

return test
