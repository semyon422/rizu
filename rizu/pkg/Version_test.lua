local Version = require("rizu.pkg.Version")

local test = {}

---@param t testing.T
function test.basic(t)
	t:lt(Version {1, 1, 1}, Version {2, 2, 2})
	t:lt(Version {1}, Version {1, 1})
	t:lt(Version {1, 1}, Version {1, 1, 1})
	t:eq(Version {1, 1, 1}, Version {1, 1, 1})
	t:assert(not (Version {1, 1} < Version {1, 1}))
end

return test
