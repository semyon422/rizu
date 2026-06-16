local TwoDx = require("chart.format.iidx.TwoDx")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

---@param t testing.T
function test.parse_payloads(t)
	local archive = TwoDx.parse(Fixtures.twoDx("test", {"sample1", "sample2"}))

	t:eq(archive.count, 2)
	t:eq(TwoDx.payload(archive, 1), "sample1")
	t:eq(TwoDx.payload(archive, 2), "sample2")
	t:eq(TwoDx.payload(archive, 3), nil)
end

return test
