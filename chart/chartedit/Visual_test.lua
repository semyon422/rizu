local table_util = require("table_util")
local Visual = require("chart.chartedit.Visual")
local Point = require("chart.chartedit.Point")

local test = {}

function test.get_point(t)
	local vis = Visual()

	local p1 = Point()
	local p2 = Point()
	table_util.to_linked({p1, p2})

	local vp1 = vis:getPoint(p1)
	local vp2 = vis:getPoint(p2)

	t:tdeq(table_util.to_array(vp1), {vp1, vp2})
end

function test.create_before(t)
	local vis = Visual()

	local p = Point()
	local vp2 = vis:getPoint(p)
	local vp0 = vis:createBefore(vp2)
	t:eq(vis:getPoint(p), vp0)

	local vp1 = vis:createBefore(vp2)
	t:eq(vis:getPoint(p), vp0)

	t:tdeq(table_util.to_array(vp0), {vp0, vp1, vp2})
end

function test.create_after(t)
	local vis = Visual()

	local p = Point()
	local vp0 = vis:getPoint(p)
	local vp2 = vis:createAfter(vp0)
	t:eq(vis:getPoint(p), vp0)

	local vp1 = vis:createAfter(vp0)
	t:eq(vis:getPoint(p), vp0)

	t:tdeq(table_util.to_array(vp0), {vp0, vp1, vp2})
end

function test.remove_0(t)
	local vis = Visual()

	local vp0 = vis:getPoint(Point())
	vis:remove(vp0)

	t:assert(not vis.head)
end

function test.remove_1(t)
	local vis = Visual()

	local vp0 = vis:getPoint(Point())
	local vp1 = vis:createAfter(vp0)
	local vp2 = vis:createAfter(vp1)

	vis:remove(vp0)

	t:eq(vis.head, vp1)
	t:tdeq(table_util.to_array(vp1), {vp1, vp2})
end

function test.remove_2(t)
	local vis = Visual()

	local vp0 = vis:getPoint(Point())
	local vp1 = vis:createAfter(vp0)
	local vp2 = vis:createAfter(vp1)

	vis:remove(vp1)

	t:eq(vis.head, vp0)
	t:tdeq(table_util.to_array(vp0), {vp0, vp2})
end

function test.remove_3(t)
	local vis = Visual()

	local vp0 = vis:getPoint(Point())
	local vp1 = vis:createAfter(vp0)
	local vp2 = vis:createAfter(vp1)

	vis:remove(vp2)

	t:eq(vis.head, vp0)
	t:tdeq(table_util.to_array(vp0), {vp0, vp1})
end

function test.remove_4(t)
	local vis = Visual()

	local p0 = Point()
	local p1 = Point()
	table_util.to_linked({p0, p1})

	local vp0 = vis:getPoint(p0)
	local vp1 = vis:createAfter(vp0)

	local vp2 = vis:getPoint(p1)
	local vp3 = vis:createAfter(vp2)

	vis:remove(vp2)

	t:eq(vis:getPoint(p0), vp0)
	t:eq(vis:getPoint(p1), vp3)
	t:tdeq(table_util.to_array(vp0), {vp0, vp1, vp3})
end

function test.lt(t)
	local vis = Visual()

	local p0 = Point()

	local vp0 = vis:getPoint(p0)
	local vp1 = vis:createAfter(vp0)
	local vp2 = vis:createAfter(vp1)

	t:assert(vp0 < vp1)
	t:assert(vp0 < vp2)
	t:assert(vp1 < vp2)
	t:assert(not (vp0 < vp0))
	t:assert(not (vp1 < vp0))
	t:assert(not (vp2 < vp0))
	t:assert(not (vp1 < vp1))
	t:assert(not (vp2 < vp1))
	t:assert(not (vp2 < vp2))
end

return test
