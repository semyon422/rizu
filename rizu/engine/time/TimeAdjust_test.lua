local TimeAdjust = require("rizu.engine.time.TimeAdjust")

local test = {}

---@param t testing.T
function test.no_adjust_const_adj_time(t)
	local ta = TimeAdjust()

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(1, 0), nil)
	t:eq(ta:adjust(2, 0), nil)
end

---@param t testing.T
function test.changing_adj_time_equal(t)
	local ta = TimeAdjust()

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(1, 1), 1)
	t:eq(ta:adjust(2, 2), 2)
end

---@param t testing.T
function test.time_ahead_factor_1(t)
	local ta = TimeAdjust(1)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(2, 0), nil)
	t:eq(ta:adjust(2, 1), 1)
	t:eq(ta:adjust(3, 1.5), 1.5)
	t:eq(ta:adjust(3, 2), 2)
	t:eq(ta:adjust(3, 2), nil)
end

---@param t testing.T
function test.time_ahead_factor_0(t)
	local ta = TimeAdjust(0)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(2, 0), nil)
	t:eq(ta:adjust(2, 1), 2)
	t:eq(ta:adjust(3, 1.5), 3)
	t:eq(ta:adjust(3, 2), 3)
	t:eq(ta:adjust(3, 2), nil)
end

---@param t testing.T
function test.time_ahead_factor_05(t)
	local ta = TimeAdjust(0.5)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(2, 0), nil)
	t:eq(ta:adjust(2, 1), 1.5)
	t:eq(ta:adjust(3, 1.5), 2.25)
	t:eq(ta:adjust(3, 2), 2.5)
	t:eq(ta:adjust(3, 2), nil)
end

---@param t testing.T
function test.time_behind_factor_1(t)
	local ta = TimeAdjust(1)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(0, 1), 1)
	t:eq(ta:adjust(0, 1), nil)
end

---@param t testing.T
function test.time_behind_factor_0(t)
	local ta = TimeAdjust(0)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(0, 1), 0)
	t:eq(ta:adjust(0, 1), nil)
end

---@param t testing.T
function test.time_behind_factor_05(t)
	local ta = TimeAdjust(0.5)

	t:eq(ta:adjust(0, 0), 0)
	t:eq(ta:adjust(0, 1), 0.5)
	t:eq(ta:adjust(0, 1), nil)
end

return test
