local SphLines = require("sph.SphLines")
local Fraction = require("ncdk.Fraction")

local test = {}

---@param t testing.T
function test.decenc_1(t)
	local sl = SphLines()

	local lines_in = {
		{},
		{offset = 0},
		{},
		{time = Fraction(1, 2)},
		{},
		{time = Fraction(1, 2), notes = {true}},
		{},
		{offset = 1},
		{},
	}
	local lines_out = {
		{offset = 0},
		{},
		{},
		{time = Fraction(1, 2), notes = {true}},
		{},
		{offset = 1},
	}
	sl:decode(lines_in)
	local lines = sl:encode()
	t:tdeq(lines, lines_out)
end

---@param t testing.T
function test.decenc_visuals(t)
	local sl = SphLines()

	local lines_in = {
		{offset = 0},
		{},
		{notes = {true}},
		{notes = {true}, same = true},
		{notes = {true}, same = true, visual = ""},
		{notes = {true}, same = true, visual = "1"},
		{notes = {true}, same = true, visual = "2"},
		{notes = {true}, same = true, visual = "3"},
		{},
		{offset = 1},
	}
	local lines_out = {
		{offset = 0},
		{},
		{notes = {true}},
		{notes = {true}, same = true},
		{notes = {true}, same = true, visual = ""},
		{notes = {true}, same = true, visual = "1"},
		{notes = {true}, same = true, visual = "2"},
		{notes = {true}, same = true, visual = "3"},
		{},
		{offset = 1},
	}
	sl:decode(lines_in)
	local lines = sl:encode()
	t:tdeq(lines, lines_out)
end

---@param t testing.T
function test.protoLines_globalTime_mixed(t)
	local sl = SphLines()

	local lines_in = {
		{offset = 0},
		{},
		{notes = {true}},
		{time = Fraction(3, 4), notes = {true}},
		{notes = {true}},
		{offset = 5},
	}

	sl:decode(lines_in)

	t:eq(sl.protoLines[1].globalTime, Fraction(0))
	t:eq(sl.protoLines[2].globalTime, Fraction(2))
	t:eq(sl.protoLines[3].globalTime, Fraction(2) + Fraction(3, 4))
end

---@param t testing.T
function test.protoLines_globalTime_early_frac(t)
	local sl = SphLines()

	local lines_in = {
		{time = Fraction(1, 2), notes = {true}},
		{},
		{},
		{},
		{offset = 0},
		{offset = 1},
	}

	sl:decode(lines_in)

	t:eq(sl.protoLines[1].globalTime, Fraction(-7, 2))
	t:eq(sl.protoLines[2].globalTime, Fraction(0))
	t:eq(sl.protoLines[3].globalTime, Fraction(1))

	local lines = sl:encode()
	t:tdeq(lines, lines_in)
end

---@param t testing.T
function test.protoLines_globalTime_first_ivl_frac(t)
	local sl = SphLines()

	local lines_in = {
		{offset = 0, time = Fraction(1, 2), notes = {true}},
		{offset = 1},
	}

	sl:decode(lines_in)

	t:eq(sl.protoLines[1].globalTime, Fraction(1, 2))
	t:eq(sl.protoLines[2].globalTime, Fraction(1))

	local lines = sl:encode()
	t:tdeq(lines, lines_in)
end

return test
