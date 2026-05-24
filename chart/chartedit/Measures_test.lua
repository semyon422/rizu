local Measures = require("chart.chartedit.Measures")
local table_util = require("table_util")

local test = {}

local function gen_points(n)
	local p = {}
	for i = 1, n do
		p[i] = {i}
	end
	return p
end

function test.empty(t)
	local measures = Measures()
	local p = gen_points(3)
	table_util.to_linked(p)

	measures:insert(p[2])

	t:assert(not p[1]._measure)
	t:assert(p[2]._measure)
	t:assert(not p[3]._measure)

	local m = p[2]._measure
	t:eq(p[1].measure, m)
	t:eq(p[2].measure, m)
	t:eq(p[3].measure, m)

	measures:remove(p[2])

	t:assert(not p[1]._measure)
	t:assert(not p[2]._measure)
	t:assert(not p[3]._measure)

	t:assert(not p[1].measure)
	t:assert(not p[2].measure)
	t:assert(not p[3].measure)
end

function test._2nd_before(t)
	local measures = Measures()
	local p = gen_points(5)
	table_util.to_linked(p)

	measures:insert(p[4])
	measures:insert(p[2])

	t:assert(not p[1]._measure)
	t:assert(p[2]._measure)
	t:assert(not p[3]._measure)
	t:assert(p[4]._measure)
	t:assert(not p[5]._measure)

	local m1 = p[2]._measure
	local m2 = p[4]._measure
	t:eq(p[1].measure, m1)
	t:eq(p[2].measure, m1)
	t:eq(p[3].measure, m1)
	t:eq(p[4].measure, m2)
	t:eq(p[5].measure, m2)

	measures:remove(p[2])

	t:assert(not p[1]._measure)
	t:assert(not p[2]._measure)
	t:assert(not p[3]._measure)
	t:assert(p[4]._measure)
	t:assert(not p[5]._measure)

	t:eq(p[1].measure, m2)
	t:eq(p[2].measure, m2)
	t:eq(p[3].measure, m2)
	t:eq(p[4].measure, m2)
	t:eq(p[5].measure, m2)
end

function test._2nd_after(t)
	local measures = Measures()
	local p = gen_points(5)
	table_util.to_linked(p)

	measures:insert(p[2])
	measures:insert(p[4])

	local m1 = p[2]._measure
	local m2 = p[4]._measure
	t:assert(m1)
	t:assert(m2)
	t:assert(not p[1]._measure)
	t:assert(not p[3]._measure)
	t:assert(not p[5]._measure)

	t:eq(p[1].measure, m1)
	t:eq(p[2].measure, m1)
	t:eq(p[3].measure, m1)
	t:eq(p[4].measure, m2)
	t:eq(p[5].measure, m2)

	measures:remove(p[4])

	t:assert(not p[1]._measure)
	t:assert(p[2]._measure)
	t:assert(not p[3]._measure)
	t:assert(not p[4]._measure)
	t:assert(not p[5]._measure)

	t:eq(p[1].measure, m1)
	t:eq(p[2].measure, m1)
	t:eq(p[3].measure, m1)
	t:eq(p[4].measure, m1)
	t:eq(p[5].measure, m1)
end

function test._3rd_between(t)
	local measures = Measures()
	local p = gen_points(7)
	table_util.to_linked(p)

	measures:insert(p[2])
	measures:insert(p[6])
	measures:insert(p[4])

	t:assert(not p[1]._measure)
	t:assert(p[2]._measure)
	t:assert(not p[3]._measure)
	t:assert(p[4]._measure)
	t:assert(not p[5]._measure)
	t:assert(p[6]._measure)
	t:assert(not p[7]._measure)

	local m1 = p[2]._measure
	local m2 = p[4]._measure
	local m3 = p[6]._measure
	t:eq(p[1].measure, m1)
	t:eq(p[2].measure, m1)
	t:eq(p[3].measure, m1)
	t:eq(p[4].measure, m2)
	t:eq(p[5].measure, m2)
	t:eq(p[6].measure, m3)
	t:eq(p[7].measure, m3)

	measures:remove(p[4])

	t:assert(not p[1]._measure)
	t:assert(p[2]._measure)
	t:assert(not p[3]._measure)
	t:assert(not p[4]._measure)
	t:assert(not p[5]._measure)
	t:assert(p[6]._measure)
	t:assert(not p[7]._measure)

	t:eq(p[1].measure, m1)
	t:eq(p[2].measure, m1)
	t:eq(p[3].measure, m1)
	t:eq(p[4].measure, m1)
	t:eq(p[5].measure, m1)
	t:eq(p[6].measure, m3)
	t:eq(p[7].measure, m3)
end

return test
