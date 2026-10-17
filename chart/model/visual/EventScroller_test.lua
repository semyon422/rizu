local EventScroller = require("chart.model.visual.EventScroller")

local test = {}

---@param t testing.T
function test.inf(t)
	local events = {
		{time = -math.huge, action = 1, point = -math.huge},
		{time = 1, action = 1, point = 1},
		{time = math.huge, action = 1, point = math.huge},
	}

	local es = EventScroller(events)

	local res = {}
	local function f(vp)
		table.insert(res, vp)
	end

	es:scroll(0, f)
	t:tdeq(res, {-math.huge})
	res = {}

	es:scroll(0, f)
	t:tdeq(res, {})
	res = {}

	es:scroll(1, f)
	t:tdeq(res, {1})
	res = {}

	es:scroll(2, f)
	t:tdeq(res, {})
end

return test
