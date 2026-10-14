local RateFormatter = require("ui.formatters.RateFormatter")

local test = {}

---@param t testing.T
function test.format(t)
	t:eq(RateFormatter.format(1, "linear"), "1.00x")
	t:eq(RateFormatter.format(1.05, "linear"), "1.05x")
	t:eq(RateFormatter.format(3, "exp"), "+3")
	t:eq(RateFormatter.format(0, "exp"), "0")
	t:eq(RateFormatter.format(-2, "exp"), "-2")
end

return test
