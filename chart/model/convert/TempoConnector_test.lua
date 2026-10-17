local TempoConnector = require("chart.model.convert.TempoConnector")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.basic(t)
	local tc = TempoConnector(4, 0.005)

	t:tdeq({tc:connect(0, 1, 0.001)}, {Fraction(1), false, 1})
	t:tdeq({tc:connect(0, 1, 0.006)}, {Fraction(1), false, 1})

	t:tdeq({tc:connect(0, 1, 0.249)}, {Fraction(1), false, 1})
	t:tdeq({tc:connect(0, 1, 0.250)}, {Fraction(1), false, 1})
	t:tdeq({tc:connect(0, 1, 0.251)}, {Fraction(1), false, 1})
	t:tdeq({tc:connect(0, 1, 0.256)}, {Fraction(1, 4), true, 1})

	t:tdeq({tc:connect(0, 1, 0.5)}, {Fraction(1, 4), true, 1})
	t:tdeq({tc:connect(0, 1, 0.506)}, {Fraction(2, 4), true, 1})

	t:tdeq({tc:connect(0, 1, 1.5)}, {Fraction(5, 4), true, 2})
	t:tdeq({tc:connect(0, 1, 1.501)}, {Fraction(5, 4), true, 2})
	t:tdeq({tc:connect(0, 1, 1.506)}, {Fraction(6, 4), true, 2})

	t:tdeq({tc:connect(0, 1, 1.994)}, {Fraction(7, 4), true, 2})
	t:tdeq({tc:connect(0, 1, 1.999)}, {Fraction(2), false, 2})
	t:tdeq({tc:connect(0, 1, 2.001)}, {Fraction(2), false, 2})
	t:tdeq({tc:connect(0, 1, 2.006)}, {Fraction(2), true, 3})
end

return test
