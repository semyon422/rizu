local InputMode = require("chart.core.InputMode")
local GameplayInteractor = require("rizu.gameplay.GameplayInteractor")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local InputBinder = require("rizu.input.InputBinder")
local TestChartFactory = require("sea.chart.TestChartFactory")
local TimingValues = require("sea.chart.TimingValues")

local test = {}

---@param t testing.T
function test.uses_computed_chart_input_mode(t)
	local chart = {inputMode = InputMode("10key")}
	t:eq(GameplayInteractor.getInputMode(chart), "10key")
end

---@param t testing.T
function test.paused_input_updates_binding(t)
	local session = {receive = function() end}
	local binder = InputBinder({["4key"] = {{{"a", "keyboard", 1}}}}, "4key")
	local interactor = setmetatable({
		game = {global_timer = {getTime = function() return 0 end}},
		gameplay_session = session,
		input_binder = binder,
	}, {__index = GameplayInteractor})
	---@cast interactor rizu.GameplayInteractor
	t:has_not_error(function()
		interactor:receive({name = "inputchanged", "keyboard", 1, "a", true})
	end)
end

---@param t testing.T
function test.direct_engine_pause_preserves_long_note_and_binding(t)
	local re = RhythmEngine()
	local session = GameplaySession(re)
	local res = TestChartFactory():create("4key", {
		{time = 2, column = 1, end_time = 5},
		{time = 6, column = 1},
	})
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:setTimingValues(TimingValues())
	re:load()
	re:setAudioEnabled(false)
	re:setPlayTime(0, 10)
	session:update(0)
	session:play()
	re:setTime(0)
	session:update(2)
	local time = 2
	local interactor = setmetatable({
		game = {global_timer = {getTime = function() return time end}},
		gameplay_session = session,
		input_binder = InputBinder({["4key"] = {
			{{"a", "keyboard", 1}},
			{{"s", "keyboard", 1}},
		}}, "4key"),
	}, {__index = GameplayInteractor})
	---@cast interactor rizu.GameplayInteractor

	interactor:receive({name = "inputchanged", "keyboard", 1, "a", true})
	local id = session.replay_recorder.frames[1].event.id
	local note = re.input_engine.event_catches[id]
	t:assert(note)

	-- PauseModel pauses the engine directly, not the session.
	re:pause()
	t:eq(session:isPaused(), true)
	time = 3
	interactor:receive({name = "inputchanged", "keyboard", 1, "a", false})
	interactor:receive({name = "inputchanged", "keyboard", 1, "s", true})
	interactor:receive({name = "inputchanged", "keyboard", 1, "a", true})
	t:eq(#session.replay_recorder.frames, 4)
	id = session.replay_recorder.frames[4].event.id
	t:eq(re.input_engine.event_catches[id], note)
	t:eq(re:isColumnPressed(1), true)
	t:eq(re:isColumnPressed(2), true)

	session:update(time)
	re:play()
	t:eq(session:isPaused(), false)
	t:eq(re.input_engine.event_catches[id], note)
	time = 4
	session:update(time)
	interactor:receive({name = "inputchanged", "keyboard", 1, "a", false})
	t:eq(#session.replay_recorder.frames, 5)
	t:eq(session.replay_recorder.frames[5].event.id, id)
	t:eq(re.input_engine.event_catches[id], nil)
	t:eq(re:isColumnPressed(1), false)
end

return test
