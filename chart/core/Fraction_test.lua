local Fraction = require("chart.core.Fraction")

local test = {}

---@param t testing.T
function test.basic(t)
	t:eq(Fraction(), Fraction(0))
	t:eq(Fraction(nil), Fraction(0))
	t:eq(Fraction() + nil, Fraction(0))

	t:eq(Fraction(0, 1), Fraction(0, 2))
	t:eq(Fraction(2, 1), Fraction(2))
	t:eq(Fraction(-1, 1), Fraction(1, -1))
	t:eq(Fraction(15, 9), Fraction(5, 3))
	t:eq(Fraction(Fraction(15), Fraction(9)), Fraction(5, 3))
	t:eq(Fraction(15, Fraction(9)), Fraction(5, 3))
	t:eq(Fraction(Fraction(15), 9), Fraction(5, 3))

	t:lt(Fraction(1), Fraction(2))
	t:le(Fraction(1), Fraction(2))
	t:le(Fraction(2), Fraction(2))

	t:eq(-Fraction(2), Fraction(-2))

	t:eq(Fraction(1, 2):tonumber(), 1 / 2)
	t:eq(Fraction(5, 4) % 1, Fraction(1, 4))
	t:eq(Fraction(-5, 4) % 1, Fraction(3, 4))
	t:eq(8 % Fraction(3), 2)
	t:le(math.abs(1.1 % Fraction(1001, 1000) - 0.099), 1e-6)

	-- __mod(a, b) return a - b * (a / b):floor() end
	-- for i = -10, 10 do for j = -10, 10 do for k = -10, 10 do for l = -10, 10 do
	-- 	if j * k * l ~= 0 then
	-- 		assert(
	-- 			math.abs(((i + 1e-9) / j) % (k / l) - Fraction(i, j) % Fraction(k, l)) < 1e-6 or
	-- 			math.abs(((i - 1e-9) / j) % (k / l) - Fraction(i, j) % Fraction(k, l)) < 1e-6
	-- 		)
	-- 	end
	-- end end end end

	t:eq(tostring(Fraction()), "0.0/1")
	t:eq(tostring(Fraction(1, 2)), "0.1/2")
	t:eq(tostring(Fraction(1)), "1.0/1")
	t:eq(tostring(Fraction(-3, 2)), "-1.1/2")
	t:eq(tostring(Fraction(-5, 3)), "-1.2/3")
	t:eq(tostring(Fraction(-1, 3)), "-0.1/3")

	t:eq(type(Fraction(1) + 1), "table")
	t:eq(type(Fraction(1) - 1), "table")
	t:eq(type(Fraction(1) * 1), "table")
	t:eq(type(Fraction(1) / 1), "table")
	t:eq(type(1 + Fraction(1)), "number")
	t:eq(type(1 - Fraction(1)), "number")
	t:eq(type(1 * Fraction(1)), "number")
	t:eq(type(1 / Fraction(1)), "number")

	t:eq(Fraction(1, 2) + 1, Fraction(3, 2))
	t:eq(1 + Fraction(1, 2), 3 / 2)

	t:eq(Fraction(1, 2) + 0, Fraction(1, 2))
	t:eq(Fraction(1, 2) + Fraction(2, 3), Fraction(7, 6))
	t:eq(Fraction(1, 2) - Fraction(2, 3), -Fraction(1, 6))

	t:eq(Fraction(1, 2) * 1, Fraction(1, 2))
	t:eq(Fraction(5, 3) * Fraction(7, 11), Fraction(35, 33))
	t:eq(Fraction(5, 3) / Fraction(7, 11), Fraction(55, 21))

	t:eq(Fraction(3, 2):ceil(), 2)
	t:eq(Fraction(3, 2):floor(), 1)
	t:eq(Fraction(-3, 2):ceil(), -1)
	t:eq(Fraction(-3, 2):floor(), -2)

	t:eq(Fraction(1.234, 1, true), Fraction(1, 1))
	t:eq(Fraction(-1.234, 1, true), Fraction(-1, 1))
	t:eq(Fraction(1.234, 10, true), Fraction(12, 10))
	t:eq(Fraction(1.234, 100, true), Fraction(123, 100))

	t:eq(Fraction(1.234, 1, false), Fraction(1, 1))
	t:eq(Fraction(-1.234, 1, false), Fraction(-1, 1))
	t:eq(Fraction(1.234, 10, false), Fraction(11, 9))
	t:eq(Fraction(1.234, 100, false), Fraction(58, 47))

	collectgarbage("stop")
	assert(("%p"):format(Fraction(99, 101)) == ("%p"):format(Fraction(100, 101) - Fraction(1, 101)))
	collectgarbage("restart")

	local f = Fraction(99, 101)
	local p = ("%p"):format(f)
	f = nil
	collectgarbage("collect")
	collectgarbage("collect")
	assert(p ~= ("%p"):format(Fraction(99, 101)))

	t:eq(Fraction(1.5, 16, false), Fraction(3, 2))
	t:eq(Fraction(0.5000001, 16, false), Fraction(1, 2))
	t:eq(Fraction(0.5000001, 16, "closest_gte"), Fraction(8, 15))
	t:eq(Fraction(0.4999999, 16, "closest_lte"), Fraction(7, 15))
	t:eq(Fraction(0.5, 16, "closest_gte"), Fraction(1, 2))
	t:eq(Fraction(0.5, 16, "closest_lte"), Fraction(1, 2))
	t:eq(Fraction(0, 16, "closest_gte"), Fraction(0, 1))
	t:eq(Fraction(0, 16, "closest_lte"), Fraction(0, 1))

	t:eq(
		t:has_error(Fraction, 0, 1.1),
		"invalid denominator: 1.1000000000000000888"
	)
	t:eq(
		t:has_error(Fraction, 1, 0),
		"invalid denominator: 0"
	)
	t:eq(
		t:has_error(Fraction, {2220394914790230.75, 1}),
		"invalid numerator: 2220394914790230.75"
	)
end

return test
