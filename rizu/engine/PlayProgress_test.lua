local PlayProgress = require("rizu.engine.PlayProgress")

local test = {}

---@param t testing.T
function test.all(t)
	local p = PlayProgress()

	p.init_time = -9
	p.start_time = 1
	p.duration = 100

	t:eq(p:get(p.init_time * 2), -1)
	t:eq(p:get(p.init_time), -1)
	t:aeq(p:get(0), -0.1, 1e-6)
	t:eq(p:get(p.start_time), 0)
	t:eq(p:get(p.start_time + p.duration / 2), 0.5)
	t:eq(p:get(p.start_time + p.duration), 1)
	t:eq(p:get(p.start_time + p.duration * 2), 1)
end

return test
