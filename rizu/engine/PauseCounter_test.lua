local PauseCounter = require("rizu.engine.PauseCounter")

local test = {}

---@param t testing.T
function test.all(t)
	local pc = PauseCounter()

	pc:setPlayTime(0, 10)

	pc:pause()
	t:eq(pc.count, 0)
	t:eq(pc.paused, true)

	pc:play(-1)
	t:eq(pc.count, 0)

	pc:pause()
	pc:play(0)
	t:eq(pc.count, 1)

	pc:pause()
	pc:play(10)
	t:eq(pc.count, 2)

	pc:pause()
	pc:play(20)
	t:eq(pc.count, 2)

	pc:pause()
	pc:play(5)
	t:eq(pc.count, 3)

	pc:play(5)
	t:eq(pc.count, 3)
end

return test
