local RhythmEngine = require("rizu.gameplay.mania.Engine")
local AutoplayPlayer = require("rizu.engine.autoplay.AutoplayPlayer")
local TestChartFactory = require("sea.chart.TestChartFactory")
local TimingValues = require("sea.chart.TimingValues")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.autoplay_short_note(t)
	local re = RhythmEngine()
	local ap = AutoplayPlayer()

	local res = tcf:create("4key", {
		{time = 1, column = 1},
		{time = 2, column = 2},
	})

	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()

	local received_events = {}
	re.receive = function(self, event)
		table.insert(received_events, {id = event.id, value = event.value, time = re:getTime()})
	end

	re:setTime(0)
	ap:update(re, 0.9)
	t:eq(#received_events, 0)

	ap:update(re, 1.1)
	t:eq(#received_events, 2)
	if received_events[1] then
		t:eq(received_events[1].value, true)
		t:eq(received_events[1].time, 1.0)
	end
	if received_events[2] then
		t:eq(received_events[2].value, false)
		t:eq(received_events[2].time, 1.0)
	end
end

---@param t testing.T
function test.autoplay_long_note(t)
	local re = RhythmEngine()
	local ap = AutoplayPlayer()

	local res = tcf:create("4key", {
		{time = 1, column = 1, end_time = 2},
	})

	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()

	local received_events = {}
	re.receive = function(self, event)
		table.insert(received_events, {id = event.id, value = event.value, time = re:getTime()})
	end

	re:setTime(0)
	ap:update(re, 0.9)
	t:eq(#received_events, 0)

	ap:update(re, 1.1)
	t:eq(#received_events, 1)
	if received_events[1] then
		t:eq(received_events[1].value, true)
		t:eq(received_events[1].time, 1.0)
	end

	ap:update(re, 1.9)
	t:eq(#received_events, 1)

	ap:update(re, 2.1)
	t:eq(#received_events, 2)
	if received_events[2] then
		t:eq(received_events[2].value, false)
		t:eq(received_events[2].time, 2.0)
	end
end

return test
