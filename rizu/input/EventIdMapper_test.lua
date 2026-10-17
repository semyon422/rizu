local EventIdMapper = require("rizu.input.EventIdMapper")

local test = {}

---@param t testing.T
function test.all(t)
	local m = EventIdMapper()

	t:eq(m:get('a'), 1)
	t:eq(m:get('a'), 1)

	t:eq(m:get('b'), 2)
	t:eq(m:get('b'), 2)

	t:eq(m:free('a'))
	t:eq(m:get('c'), 1)
	t:eq(m:get('d'), 3)
end

return test
