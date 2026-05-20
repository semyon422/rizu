local VisualPoint = require("chart.model.visual.VisualPoint")
local Velocity = require("chart.model.visual.Velocity")
local Expand = require("chart.model.visual.Expand")
local Visual = require("chart.model.visual.Visual")
local Point = require("chart.model.tp.Point")
local Tempo = require("chart.model.to.Tempo")

local test = {}

function test.basic(t)
	local vis = Visual()

	local vp0 = vis:newPoint(Point(-1))
	local vp1 = vis:newPoint(Point(1))
	local vp2 = vis:newPoint(Point(2))
	local vp3 = vis:newPoint(Point(3))

	vp1._velocity = Velocity(2)
	vp2._velocity = Velocity(3)

	vis:compute()

	t:eq(vp0.visualTime, -2)
	t:eq(vp1.visualTime, 2)
	t:eq(vp2.visualTime, 4)
	t:eq(vp3.visualTime, 7)

	t:eq(vp0.monotonicVisualTime, -2)
	t:eq(vp3.monotonicVisualTime, 7)
end

function test.no_zero_point(t)
	local vis = Visual()

	local vp1 = vis:newPoint(Point(-1))
	local vp2 = vis:newPoint(Point(1))

	vp1._velocity = Velocity()

	vis:compute()

	t:eq(vp1.visualTime, -1)
	t:eq(vp2.visualTime, 1)

	t:eq(vp1.monotonicVisualTime, -1)
	t:eq(vp2.monotonicVisualTime, 1)
end

function test.inf_expand(t)
	local vis = Visual()

	local vp0 = vis:newPoint(Point(0))

	local point = Point(5)
	local vp1 = vis:newPoint(point)
	local vp2 = vis:newPoint(point)
	local vp3 = vis:newPoint(point)

	local vp10 = vis:newPoint(Point(10))

	vp1._expand = Expand(math.huge)

	vis:compute()

	t:eq(vp1:getVisualTime(vp0), 5)
	t:eq(vp2:getVisualTime(vp0), math.huge)
	t:eq(vp3:getVisualTime(vp0), math.huge)

	t:eq(vp1:getVisualTime(vp10), -math.huge)
	t:eq(vp2:getVisualTime(vp10), 5)
	t:eq(vp3:getVisualTime(vp10), 5)
end

function test.inf_expand_back(t)
	local vis = Visual()

	local vp0 = vis:newPoint(Point(0))

	local point = Point(5)
	local vp1 = vis:newPoint(point)
	local vp2 = vis:newPoint(point)
	local vp3 = vis:newPoint(point)
	local vp4 = vis:newPoint(point)
	local vp5 = vis:newPoint(point)

	local vp10 = vis:newPoint(Point(10))

	vp1._expand = Expand(math.huge)
	vp2._expand = Expand(1)
	vp3._expand = Expand(-math.huge)

	vis:compute()

	t:eq(vp1:getVisualTime(vp0), 5)
	t:eq(vp2:getVisualTime(vp0), math.huge)
	t:eq(vp3:getVisualTime(vp0), math.huge)
	t:eq(vp4:getVisualTime(vp0), 5)
	t:eq(vp5:getVisualTime(vp0), 5)

	t:eq(vp1:getVisualTime(vp10), 5)
	t:eq(vp2:getVisualTime(vp10), math.huge)
	t:eq(vp3:getVisualTime(vp10), math.huge)
	t:eq(vp4:getVisualTime(vp10), 5)
	t:eq(vp5:getVisualTime(vp10), 5)

	t:eq(vp3:getVisualTime(vp2), 6)
end

function test.tempo(t)
	local vis = Visual()
	vis.primaryTempo = 100  -- tempo requires primaryTempo to affect visual time

	local p0 = Point(0)
	local p1 = Point(1)
	local p2 = Point(2)
	local p3 = Point(3)

	p0.tempo = Tempo(100)
	p1.tempo = Tempo(200)
	p2.tempo = Tempo(300)

	local vp0 = vis:newPoint(p0)
	local vp1 = vis:newPoint(p1)
	local vp2 = vis:newPoint(p2)
	local vp3 = vis:newPoint(p3)

	vis:compute()

	t:eq(vp0.visualTime, 0)
	t:eq(vp0.currentSpeed, 1)

	t:eq(vp1.visualTime, 1)
	t:eq(vp1.currentSpeed, 2)

	t:eq(vp2.visualTime, 3)
	t:eq(vp2.currentSpeed, 3)

	t:eq(vp3.visualTime, 6)
	t:eq(vp3.currentSpeed, 3)
end

function test.stop(t)
	local vis = Visual()
	vis.primaryTempo = 60  -- stop requires primaryTempo to affect visual time

	local p0 = Point(0)
	local p1 = Point(1)
	local p2 = Point(2)

	p0.tempo = Tempo(60)
	p1.tempo = Tempo(60)
	p2.tempo = Tempo(60)

	p0._stop = {}

	local vp0 = vis:newPoint(p0)
	local vp1 = vis:newPoint(p1)
	local vp2 = vis:newPoint(p2)

	vis:compute()

	-- the point before Stop is starting and should have speed == 0
	t:eq(vp0.visualTime, 0)
	t:eq(vp0.currentSpeed, 0)

	-- the point that have Stop is ending and should have speed ~= 0
	t:eq(vp1.visualTime, 0)
	t:eq(vp1.currentSpeed, 1)

	t:eq(vp2.visualTime, 1)
	t:eq(vp2.currentSpeed, 1)
end

function test.tempo_expand(t)
	local vis = Visual()
	vis.primaryTempo = 60

	local point = Point(0)
	point.tempo = Tempo(120)

	local vp0 = vis:newPoint(point)
	local vp1 = vis:newPoint(point)

	vp0._expand = Expand(1)  -- 1 beat

	vis:compute()

	t:eq(vp1.visualTime, 0.5)  -- 1 beat in 120 bpm is 0.5 seconds
end

function test.interval_expand(t)
	local vis = Visual()

	local point = Point(0)
	point.vertex = {getBeatDuration = function() return 60 / 120 end}

	local vp0 = vis:newPoint(point)
	local vp1 = vis:newPoint(point)

	vp0._expand = Expand(1)  -- 1 beat

	vis:compute()

	t:eq(vp1.visualTime, 0.5)  -- 1 beat in 120 bpm is 0.5 seconds
end

function test.compare(t)
	local vis = Visual()

	local p0 = Point(0)
	local p1 = Point(1)

	local vp0 = vis:newPoint(p0)
	local vp1 = vis:newPoint(p1)

	t:eq(vp0.compare_index, 1)
	t:eq(vp1.compare_index, 2)
	t:lt(vp0, vp1)

	local p05 = Point(0.5)
	local vp05 = vis:newPoint(p05)

	t:eq(vp05.compare_index, 3)
	t:lt(vp0, vp1)
	t:lt(vp0, vp05)
	t:lt(vp05, vp1)

	vis:sort()

	t:eq(vp0.compare_index, 1)
	t:eq(vp05.compare_index, 2)
	t:eq(vp1.compare_index, 3)
	t:lt(vp0, vp1)
	t:lt(vp0, vp05)
	t:lt(vp05, vp1)
end

return test
