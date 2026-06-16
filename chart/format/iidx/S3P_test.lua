local S3P = require("chart.format.iidx.S3P")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

---@param t testing.T
function test.parse_payloads(t)
	local pack = S3P.parse(Fixtures.s3p({"sample0", "sample1"}))

	t:eq(pack.count, 2)
	t:eq(S3P.sample_payload_by_id(pack, 0), nil)
	t:eq(S3P.sample_payload_by_id(pack, 1), "sample0")
	t:eq(S3P.sample_payload_by_id(pack, 2), "sample1")
	t:eq(S3P.sample_payload_by_id(pack, 3), nil)
end

return test
