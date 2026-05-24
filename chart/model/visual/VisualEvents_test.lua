local Velocity = require("chart.model.visual.Velocity")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")
local VisualEvents = require("chart.model.visual.VisualEvents")
local VisualEventsN2 = require("chart.model.visual.VisualEventsN2")
local Visual = require("chart.model.visual.Visual")

local test = {}

---@param t any
---@param es1 chart.VisualEvent[]
---@param es2 chart.VisualEvent[]
local function eq_events(t, es1, es2)
	if not t:eq(#es1, #es2) then
		return
	end
	local err = 0
	for i = 1, #es1 do
		if math.abs(es1[i].time) == math.huge then
			t:eq(es1[i].time, es2[i].time)
		else
			err = err + math.abs(es1[i].time - es2[i].time)
		end
		t:eq(es1[i].action, es2[i].action)
	end
	t:lt(err / #es1, 1e-6)
end

local function new_vp(time)
	local vp = VisualPoint(Point(time))
	vp.visualTime = time
	return vp
end

function test.basic(t)
	local vp = VisualPoint(Point(0))
	vp._velocity = Velocity(1)

	local ve = VisualEvents()

	local events = ve:generate({vp}, {-1, 1})
	t:eq(#events, 2)
	t:eq(events[1].time, -1)
	t:eq(events[1].action, 1)
	t:eq(events[2].time, 1)
	t:eq(events[2].action, -1)
end

function test.local_1(t)
	local vp_1 = VisualPoint(Point(0))
	vp_1._velocity = Velocity(1)

	local vp_2 = VisualPoint(Point(1))
	vp_2._velocity = Velocity(1, 0.5)

	local ve = VisualEvents()

	local events = ve:generate({vp_1, vp_2}, {-1, 1})
	t:eq(#events, 4)
end

function test.to_abs_basic(t)
	local vps = {
		new_vp(0),
		new_vp(1),
		new_vp(2),
	}

	local veN2 = VisualEventsN2()
	local es2 = veN2:generate(vps, {-1, 1})

	local ve = VisualEvents()
	local es1 = ve:generate(vps, {-1, 1})

	t:tdeq(es1, es2)
end

function test.to_abs_negative(t)
	local vis = Visual()

	local vp_1 = vis:newPoint(Point(0))
	local vp_2 = vis:newPoint(Point(100))

	vp_1._velocity = Velocity(-1)
	vp_2._velocity = Velocity(1)

	vis:compute()

	local ve = VisualEvents()
	local events = ve:generate(vis.points, {-1, 1})
	t:eq(#events, 6)

	local veN2 = VisualEventsN2()
	local es2 = veN2:generate(vis.points, {-1, 1})

	t:tdeq(events, es2)
end

local function rand_vel()
	return math.floor((math.random() - 0.5) * 2000) / 1000
end

function test.N2_validate(t)
	math.randomseed(12345)

	local vis = Visual()

	local time = 0
	for i = 1, 50 do
		local vp = vis:newPoint(Point(time))
		time = time + 100
		vp._velocity = Velocity(rand_vel(), rand_vel(), 1)
	end
	vis:compute()

	local veN2 = VisualEventsN2()
	local eventsN2 = veN2:generate(vis.points, {-1, 1})

	local ve = VisualEvents()
	local abs_events = ve:generate(vis.points, {-1, 1})

	for _, e in ipairs(abs_events) do
		e.point_vt = e.point.visualTime
		e.point_at = e.point.point.absoluteTime
		e.point = nil
	end
	for _, e in ipairs(eventsN2) do
		e.point_vt = e.point.visualTime
		e.point_at = e.point.point.absoluteTime
		e.point = nil
	end

	t:eq(#abs_events, #eventsN2)
	-- t:tdeq(abs_events, eventsN2)

	eq_events(t, abs_events, eventsN2)
end

function test.equal_time(t)
	local vps = {
		new_vp(0),
		new_vp(0),
		new_vp(0),
	}

	local veN2 = VisualEventsN2()
	local es2 = veN2:generate(vps, {-1, 1})

	local ve = VisualEvents()
	local es1 = ve:generate(vps, {-1, 1})

	t:tdeq(es1, es2)
	t:tdeq(es2, {
		{action=1,point={point={absoluteTime=0},visualTime=0},time=-1},
		{action=1,point={point={absoluteTime=0},visualTime=0},time=-1},
		{action=1,point={point={absoluteTime=0},visualTime=0},time=-1},
		{action=-1,point={point={absoluteTime=0},visualTime=0},time=1},
		{action=-1,point={point={absoluteTime=0},visualTime=0},time=1},
		{action=-1,point={point={absoluteTime=0},visualTime=0},time=1},
	})
end

return test
