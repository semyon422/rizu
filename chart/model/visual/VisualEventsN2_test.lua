local Velocity = require("chart.model.visual.Velocity")
local Expand = require("chart.model.visual.Expand")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")
local VisualEvents = require("chart.model.visual.VisualEvents")
local VisualEventsN2 = require("chart.model.visual.VisualEventsN2")
local Visual = require("chart.model.visual.Visual")

local test = {}

---@param events chart.VisualEvent[]
local function clear_events(events)
	for _, e in ipairs(events) do
		e.point_vt = e.point.visualTime
		e.point_at = e.point.point.absoluteTime
		e.point = nil
	end
end

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

function test.basic(t)
	local vp = VisualPoint(Point(0))
	vp._velocity = Velocity(1)

	local ve = VisualEventsN2()

	local events = ve:generate({vp}, {-1, 1})
	t:eq(#events, 2)
	t:eq(events[1].time, -1)
	t:eq(events[1].action, 1)
	t:eq(events[2].time, 1)
	t:eq(events[2].action, -1)
end

function test.expand(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
	}
	vps[2]._expand = Expand(50)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 8)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = -100, time = -101},
		{action = -1, point_at = -100, point_vt = -100, time = -99},
		{action = 1, point_at = 0, point_vt = 0, time = -1},
		{action = -1, point_at = 0, point_vt = 0, time = 0},
		{action = 1, point_at = 0, point_vt = 50, time = 0},
		{action = -1, point_at = 0, point_vt = 50, time = 1},
		{action = 1, point_at = 100, point_vt = 150, time = 99},
		{action = -1, point_at = 100, point_vt = 150, time = 101},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

function test.zero(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
		vis:newPoint(Point(200)),
	}
	vps[1]._velocity = Velocity(1)
	vps[2]._velocity = Velocity(0)
	vps[3]._velocity = Velocity(1)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 8)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = -100, time = -101},
		{action = -1, point_at = -100, point_vt = -100, time = -99},
		{action = 1, point_at = 0, point_vt = 0, time = -1},
		{action = 1, point_at = 100, point_vt = 0, time = -1},
		{action = -1, point_at = 0, point_vt = 0, time = 101},
		{action = -1, point_at = 100, point_vt = 0, time = 101},
		{action = 1, point_at = 200, point_vt = 100, time = 199},
		{action = -1, point_at = 200, point_vt = 100, time = 201},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

function test.negative(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
		vis:newPoint(Point(200)),
		vis:newPoint(Point(300)),
		vis:newPoint(Point(400)),
	}
	vps[2]._velocity = Velocity(1)
	vps[3]._velocity = Velocity(-1)
	vps[4]._velocity = Velocity(1)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 20)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = -100, time = -101},
		{action = -1, point_at = -100, point_vt = -100, time = -99},
		{action = 1, point_at = 0, point_vt = 0, time = -1},
		{action = 1, point_at = 200, point_vt = 0, time = -1},
		{action = -1, point_at = 0, point_vt = 0, time = 1},
		{action = -1, point_at = 200, point_vt = 0, time = 1},
		{action = 1, point_at = 100, point_vt = 100, time = 99},
		{action = 1, point_at = 300, point_vt = 100, time = 99},
		{action = -1, point_at = 100, point_vt = 100, time = 101},
		{action = -1, point_at = 300, point_vt = 100, time = 101},
		{action = 1, point_at = 0, point_vt = 0, time = 199},
		{action = 1, point_at = 200, point_vt = 0, time = 199},
		{action = -1, point_at = 0, point_vt = 0, time = 201},
		{action = -1, point_at = 200, point_vt = 0, time = 201},
		{action = 1, point_at = 100, point_vt = 100, time = 299},
		{action = 1, point_at = 300, point_vt = 100, time = 299},
		{action = -1, point_at = 100, point_vt = 100, time = 301},
		{action = -1, point_at = 300, point_vt = 100, time = 301},
		{action = 1, point_at = 400, point_vt = 200, time = 399},
		{action = -1, point_at = 400, point_vt = 200, time = 401},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

function test.zero_start(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
	}
	vps[1]._velocity = Velocity(0)
	vps[2]._velocity = Velocity(-1)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 6)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 0, point_vt = 0, time = -1 / 0},
		{action = -1, point_at = -100, point_vt = 0, time = 1},
		{action = -1, point_at = 0, point_vt = 0, time = 1},
		{action = 1, point_at = 100, point_vt = -100, time = 99},
		{action = -1, point_at = 100, point_vt = -100, time = 101},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

function test.zero_end(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
	}
	vps[1]._velocity = Velocity(-1)
	vps[2]._velocity = Velocity(0)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 6)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = 100, time = -101},
		{action = -1, point_at = -100, point_vt = 100, time = -99},
		{action = 1, point_at = 0, point_vt = 0, time = -1},
		{action = 1, point_at = 100, point_vt = 0, time = -1},
		{action = -1, point_at = 0, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 100, point_vt = 0, time = 1 / 0},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	t:tdeq(abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

function test.zero_both(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
		vis:newPoint(Point(200)),
		vis:newPoint(Point(300)),
		vis:newPoint(Point(400)),
	}
	vps[1]._velocity = Velocity(0)
	vps[2]._velocity = Velocity(-1)
	vps[3]._velocity = Velocity(2)
	vps[4]._velocity = Velocity(-1)
	vps[5]._velocity = Velocity(0)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 28)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 0, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 300, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 400, point_vt = 0, time = -1 / 0},

		{action = -1, point_at = -100, point_vt = 0, time = 1},
		{action = -1, point_at = 0, point_vt = 0, time = 1},
		{action = -1, point_at = 300, point_vt = 0, time = 1},
		{action = -1, point_at = 400, point_vt = 0, time = 1},

		{action = 1, point_at = 100, point_vt = -100, time = 99},
		{action = -1, point_at = 100, point_vt = -100, time = 100.5},

		{action = 1, point_at = -100, point_vt = 0, time = 149.5},
		{action = 1, point_at = 0, point_vt = 0, time = 149.5},
		{action = 1, point_at = 300, point_vt = 0, time = 149.5},
		{action = 1, point_at = 400, point_vt = 0, time = 149.5},
		{action = -1, point_at = -100, point_vt = 0, time = 150.5},
		{action = -1, point_at = 0, point_vt = 0, time = 150.5},
		{action = -1, point_at = 300, point_vt = 0, time = 150.5},
		{action = -1, point_at = 400, point_vt = 0, time = 150.5},

		{action = 1, point_at = 200, point_vt = 100, time = 199.5},
		{action = -1, point_at = 200, point_vt = 100, time = 201},

		{action = 1, point_at = -100, point_vt = 0, time = 299},
		{action = 1, point_at = 0, point_vt = 0, time = 299},
		{action = 1, point_at = 300, point_vt = 0, time = 299},
		{action = 1, point_at = 400, point_vt = 0, time = 299},

		{action = -1, point_at = -100, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 0, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 300, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 400, point_vt = 0, time = 1 / 0},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	t:tdeq(abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
	clear_events(events)
	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 0, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 100, point_vt = -100, time = -1 / 0},
		{action = 1, point_at = 200, point_vt = 100, time = -1 / 0},
		{action = 1, point_at = 300, point_vt = 0, time = -1 / 0},
		{action = 1, point_at = 400, point_vt = 0, time = -1 / 0},
		{action = -1, point_at = -100, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 0, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 100, point_vt = -100, time = 1 / 0},
		{action = -1, point_at = 200, point_vt = 100, time = 1 / 0},
		{action = -1, point_at = 300, point_vt = 0, time = 1 / 0},
		{action = -1, point_at = 400, point_vt = 0, time = 1 / 0},
	})
end

function test.zero_local_speed(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
	}
	vps[1]._velocity = Velocity(1, 1)
	vps[2]._velocity = Velocity(1, 0)
	vps[3]._velocity = Velocity(1, 1)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	t:tdeq(abs_events, events)
end

function test._local(t)
	local vis = Visual()
	local vps = {
		vis:newPoint(Point(-100)),
		vis:newPoint(Point(0)),
		vis:newPoint(Point(100)),
		vis:newPoint(Point(200)),
	}
	vps[2]._velocity = Velocity(1, 1)
	vps[3]._velocity = Velocity(1, 2)

	vis:compute()

	local ve = VisualEventsN2()
	local events = ve:generate(vps, {-1, 1})
	clear_events(events)

	t:eq(#events, 8)

	t:tdeq(events, {
		{action = 1, point_at = -100, point_vt = -100, time = -101},
		{action = -1, point_at = -100, point_vt = -100, time = -99},
		{action = 1, point_at = 0, point_vt = 0, time = -1},
		{action = -1, point_at = 0, point_vt = 0, time = 1},
		{action = 1, point_at = 100, point_vt = 100, time = 99.5},
		{action = -1, point_at = 100, point_vt = 100, time = 100.5},
		{action = 1, point_at = 200, point_vt = 200, time = 199.5},
		{action = -1, point_at = 200, point_vt = 200, time = 200.5},
	})

	----
	local ve1 = VisualEvents()
	local abs_events = ve1:generate(vps, {-1, 1})
	clear_events(abs_events)
	eq_events(t, abs_events, events)
	t:tdeq(abs_events, events)
	----

	events = ve:generate(vps, {-1000, 1000})
	t:eq(#events, #vps * 2)
end

return test
