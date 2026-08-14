local RhythmEngine = require("rizu.engine.RhythmEngine")
local TestChartFactory = require("sea.chart.TestChartFactory")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.time_to_prepare(t)
	local re = RhythmEngine()

	local res = tcf:create("4key", {
		{time = 1, column = 1},
		{time = 2, column = 2},
	})

	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:load()

	re:setPlayTime(1, 2)
	re:setTimeToPrepare(2)
	t:eq(re:getTime(), -1)

	re:setPlayTime(3, 4)
	re:setTimeToPrepare(2)
	t:eq(re:getTime(), 0)
end

---@param t testing.T
function test.skip_intro(t)
	local re = RhythmEngine()

	local res = tcf:create("4key", {
		{time = 1, column = 1},
		{time = 2, column = 2},
	})

	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:load()

	re:setPlayTime(10, 2)
	re:setTimeToPrepare(2)

	re:setTime(0)
	re:skipIntro()
	t:eq(re:getTime(), 8)
end

---@param t testing.T
function test.visual_rate_with_rate(t)
	local re = RhythmEngine()

	re:setRate(0.5)
	re:setVisualRate(1, false) -- scale_visual_rate = false

	-- visual_rate should be 1 / 0.5 = 2
	t:eq(re.visual_info.rate, 2)

	re:setRate(2)
	re:setVisualRate(1, false)
	t:eq(re.visual_info.rate, 0.5)
end

---@param t testing.T
function test.state_reset(t)
	local res = tcf:create("4key", {
		{time = 1, column = 1},
		{time = 50, column = 2},
	})

	local function create_and_run()
		local re = RhythmEngine()
		re:setChart(res.chart, res.chartmeta, res.chartdiff)
		re.audio_engine.getStartTime = function() return 100 end
		re:load()
		re:setPlayTime(1, 2)
		re:setTimeToPrepare(0.5)
		return re
	end

	local re = create_and_run()
	re:setGlobalTime(0)
	re:play()
	re:setGlobalTime(1)
	re:update()

	-- At 1.5s, some notes should be visible/active
	t:eq(re:getTime(), 1.5)
	t:assert(#re.visual_engine.visible_notes > 0)
	t:assert(#re.logic_engine.active_notes > 0)

	re:unload()
	re = create_and_run()

	-- After recreation (retry), it should be clean and time reset to init_time (0.5)
	t:eq(re:getTime(), 0.5)
	-- Initial state: only first note might be visible depending on implementation
	t:eq(#re.visual_engine.visible_notes, 1)
	t:eq(#re.logic_engine.active_notes, 2)
end

---@param t testing.T
function test.loader_order(t)
	local RhythmEngineLoader = require("rizu.gameplay.RhythmEngineLoader")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
	local TimingValues = require("sea.chart.TimingValues")
	local re = RhythmEngine()

	local res = tcf:create("4key", {
		{time = 1, column = 1},
		{time = 2, column = 2},
	})
	res.chartdiff.start_time = 10
	res.chartdiff.duration = 2

	local settings = Settings.createConfig(FakeFilesystem())

	re.audio_engine.getStartTime = function() return 100 end

	local loader = RhythmEngineLoader(
		{rate = 1, timings = {name = "sphere"}, subtimings = nil, timing_values = TimingValues(), nearest = false, const = false},
		{chart = res.chart, chartmeta = res.chartmeta, chartdiff = res.chartdiff, state = {}},
		settings,
		{}
	)

	loader:load(re)

	t:eq(re:getTime(), 8)
end

---@param t testing.T
function test.double_unload(t)
	local re = RhythmEngine()
	t:has_not_error(function()
		re:unload()
		re:unload()
	end)
end

---@param t testing.T
function test.logic_time_sync_on_receive(t)
	local re = RhythmEngine()
	
	local res = tcf:create("4key", {})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:load()
	
	re:setGlobalTime(0)
	re:play() -- Start the timer
	
	-- logic_info.time starts at 0
	re:syncTime()
	t:eq(re.logic_info.time, 0)
	
	-- 1. Verify syncTime() works
	re:setGlobalTime(1.5)
	re:syncTime()
	t:eq(re.logic_info.time, 1.5)
	
	-- 2. Verify receive() triggers sync
	re:setGlobalTime(2.5)
	-- logic_info.time should still be 1.5
	t:eq(re.logic_info.time, 1.5)
	
	-- receive() should update it to 2.5
	re:receive({id = 1, value = true})
	t:eq(re.logic_info.time, 2.5, "logic_info.time should be synced during receive")
end

return test
