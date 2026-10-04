local GameplaySession = require("rizu.gameplay.GameplaySession")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local TestChartFactory = require("sea.chart.TestChartFactory")
local TimingValues = require("sea.chart.TimingValues")
local ComputeContext = require("sea.compute.ComputeContext")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.basic_lifecycle(t)
	local re = RhythmEngine()
	local gc = GameplaySession(re)
	
	local res = tcf:create("4key", {
		{time = 2, column = 1},
		{time = 3, column = 2},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)

	-- Test play/pause
	local play_called = false
	local pause_called = false
	re.play = function() play_called = true end
	re.pause = function() pause_called = true end

	gc:play()
	t:assert(play_called)

	gc:pause()
	t:assert(pause_called)

	-- Test update
	gc:update(100)
	t:eq(re.time_engine.timer.global_time, 100)
end

---@param t testing.T
function test.autoplay(t)
	local re = RhythmEngine()
	local gc = GameplaySession(re)
	
	local res = tcf:create("4key", {
		{time = 2, column = 1},
		{time = 3, column = 2},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)
	gc:setPlayType("auto")

	local received_events = {}
	re.receive = function(self, event)
		table.insert(received_events, event)
	end

	-- Initial time setup
	gc:update(0)
	re:play()
	re:setTime(0)
	
	-- Manually advance time by updating GameplaySession with new global time
	gc:update(2.1) -- trigger note at =2
	
	t:assert(#received_events >= 2, "Autoplay should have triggered note events")
end

---@param t testing.T
function test.input_recording(t)
	local re = RhythmEngine()
	local gc = GameplaySession(re)
	
	local res = tcf:create("4key", {
		{time = 2, column = 1},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)

	local event = VirtualInputEvent(1, true, 1)
	gc:receive(event, 0)

	t:eq(#gc.replay_recorder.frames, 1)
	t:eq(gc.replay_recorder.frames[1].event.value, true)
	t:eq(gc.replay_recorder.frames[1].event.column, 1)
end

---@param t testing.T
function test.has_result(t)
	local re = RhythmEngine()
	local gc = GameplaySession(re)
	
	local res = tcf:create("4key", {
		{time = 2, column = 1},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)
	re:setPlayTime(0, 10)

	-- Should not have result initially
	t:assert(not gc:hasResult())

	-- Mock score engine to have some hits
	re.score_engine.scores.base.hitCount = 1
	re:setTime(5)
	re.score_engine.scores.normalscore.accuracyAdjusted = 0.95
	
	t:assert(gc:hasResult())
	
	-- Should NOT have result if replaying
	gc:setPlayType("replay")
	t:assert(not gc:hasResult())
	
	-- Should NOT have result if autoplay
	gc:setPlayType("auto")
	t:assert(not gc:hasResult())
end

---@param t testing.T
function test.pause_defers_input_and_preserves_long_note(t)
	local re = RhythmEngine()
	local gc = GameplaySession(re)
	local res = tcf:create("4key", {
		{time = 2, column = 1, end_time = 5},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)
	gc:update(0)
	re:setPlayTime(0, 10)
	gc:play()
	re:setTime(0)
	gc:update(2)
	gc:receive(VirtualInputEvent(1, true, 1), 2)
	local id = gc.replay_recorder.frames[1].event.id
	local note = re.input_engine.event_catches[id]
	t:assert(note)

	gc:pause()
	gc:receive(VirtualInputEvent(1, false, 1), 3)
	gc:receive(VirtualInputEvent(1, true, 1), 4)
	gc:receive(VirtualInputEvent(2, true, 2), 4)
	t:eq(#gc.replay_recorder.frames, 4)
	t:eq(gc.replay_recorder.frames[2].event.column, 1)
	t:eq(gc.replay_recorder.frames[3].event.column, 1)
	t:eq(gc.replay_recorder.frames[4].event.column, 2)
	t:eq(re:isColumnPressed(1), true)
	t:eq(re:isColumnPressed(2), true)

	gc:update(4)
	gc:play()
	t:eq(re.input_engine.event_catches[id], note)
	gc:update(5)
	gc:receive(VirtualInputEvent(1, false, 1), 5)
	t:eq(#gc.replay_recorder.frames, 5)
	t:eq(gc.replay_recorder.frames[5].event.id, id)
	t:eq(re.input_engine.event_catches[id], nil)
	t:eq(re:isColumnPressed(1), false)
end


---@param t testing.T
function test.offset_free_replay_preserves_judgements_at_rates_and_partitions(t)
	local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
	---@param rate number
	---@return rizu.RhythmEngine, rizu.GameplaySession
	local function session(rate)
		local re = RhythmEngine()
		local gc = GameplaySession(re)
		local res = tcf:create("4key", {{time = 1, column = 1}, {time = 2, column = 2}})
		re:setChart(res.chart, res.chartmeta, res.chartdiff)
		re:setTimingValues(TimingValues()); re:load(); re:setAudioEnabled(false)
		re:setRate(rate); re:setPlayTime(0, 4); re:setGlobalTime(0); re:setTime(-1); re:play()
		return re, gc
	end
	local function feed_manual(rate, partitions)
		local re, gc = session(rate)
		for i, time in ipairs({1, 2}) do
			gc:receive(VirtualInputEvent(i, true, i), (time + 1) / rate)
			for _, partition in ipairs(partitions) do
				if partition > time and partition < time + 1 then gc:update((partition + 1) / rate) end
			end
		end
		gc:update(5 / rate)
		return re, gc
	end
	for _, rate in ipairs({0.5, 1, 1.5, 2}) do
		for _, partitions in ipairs({{}, {1.25, 1.5, 1.75, 2.5}, {1.01, 1.02, 1.03, 1.99, 2.01}}) do
			local manual_re, manual = feed_manual(rate, partitions)
			local frames = ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames()))
			local replay_re, replay = session(rate)
			local computed_re = session(rate)
			ComputeContext():computePlay(computed_re, frames)
			replay:setPlayType("replay"); replay:setReplayFrames(frames)
			for _, partition in ipairs(partitions) do replay:update((partition + 1) / rate) end
			replay:update(5 / rate)
			t:eq(#manual_re.score_engine.events, 2)
			t:eq(#replay_re.score_engine.events, #manual_re.score_engine.events)
			t:eq(#computed_re.score_engine.events, #manual_re.score_engine.events)
			t:eq(#manual.replay_recorder:getFrames(), #frames)
			for i, change in ipairs(manual_re.score_engine.events) do
				local replay_change = replay_re.score_engine.events[i]
				t:aeq(change.time, replay_change.time, 1e-9); t:aeq(change.delta_time, replay_change.delta_time, 1e-9)
				t:eq(change.new_state, replay_change.new_state)
			end
			t:eq(manual_re.score_engine.scores.base.hitCount, replay_re.score_engine.scores.base.hitCount)
			t:eq(manual_re.score_engine.scores.base.missCount, replay_re.score_engine.scores.base.missCount)
			t:aeq(manual_re.score_engine.scores.normalscore.accuracyAdjusted, replay_re.score_engine.scores.normalscore.accuracyAdjusted, 1e-9)
			for i, change in ipairs(manual_re.score_engine.events) do
				local computed_change = computed_re.score_engine.events[i]
				t:aeq(change.time, computed_change.time, 1e-9); t:aeq(change.delta_time, computed_change.delta_time, 1e-9)
				t:eq(change.new_state, computed_change.new_state)
			end
			t:eq(manual_re.score_engine.scores.base.hitCount, computed_re.score_engine.scores.base.hitCount)
			t:eq(manual_re.score_engine.scores.base.missCount, computed_re.score_engine.scores.base.missCount)
			t:aeq(manual_re.score_engine.scores.normalscore.accuracyAdjusted, computed_re.score_engine.scores.normalscore.accuracyAdjusted, 1e-9)
		end
	end
end

return test
