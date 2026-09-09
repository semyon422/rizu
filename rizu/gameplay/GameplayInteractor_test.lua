local ReplayBase = require("sea.replays.ReplayBase")
local InputMode = require("chart.core.InputMode")
local GameplayInteractor = require("rizu.gameplay.GameplayInteractor")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local InputBinder = require("rizu.input.InputBinder")
local TestChartFactory = require("sea.chart.TestChartFactory")
local TimingValues = require("sea.chart.TimingValues")
local PauseModel = require("sphere.models.PauseModel")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")

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

---@param t testing.T
function test.retry_request_starts_one_fresh_attempt(t)
	for _, state in ipairs({"play", "pause"}) do
		local settings = Settings.createConfig(FakeFilesystem())
		settings:setNumber(Settings.keys.gameplay.time_play_retry, 0)
		settings:setNumber(Settings.keys.gameplay.time_pause_retry, 0)
		local pause_model = PauseModel(settings, {})
		pause_model:load()
		pause_model.state = state
		local attempts = 0
		local plays = 0
		local session = {update = function() end}
		local interactor = setmetatable({
			loaded = true,
			autoplay = true,
			gameplay_session = session,
			game = {
				pauseModel = pause_model,
				global_timer = {getTime = function() return 10 end},
				multiplayerModel = {client = {isInRoom = function() return false end}},
				replayBase = {timings = "simple", subtimings = "normal"},
				rhythm_engine = {setTimings = function(_, timings, subtimings)
					t:eq(timings, "simple")
					t:eq(subtimings, "normal")
				end},
			},
			load = function(self, autoplay)
				t:eq(autoplay, true)
				attempts = attempts + 1
				self.gameplay_session = {update = function() end, play = function()
					plays = plays + 1
				end}
			end,
		}, {__index = GameplayInteractor})
		---@cast interactor rizu.GameplayInteractor

		interactor:changePlayState("retry")
		t:eq(pause_model.needRetry, true)
		interactor:update()
		t:ne(interactor.gameplay_session, session)
		t:eq(attempts, 1)
		t:eq(plays, 1)
		t:eq(pause_model.needRetry, false)
		t:eq(pause_model.state, "play")
		interactor:update()
		t:eq(attempts, 1)
	end
end

---@param t testing.T
function test.aim_deadlines_wait_for_queued_input_and_score_is_never_saved(t)
	local updates, saves = 0, 0
	local re = {aim_rules = {}, unloadAudio = function() end, setTime = function() end}
	local session = {
		rhythm_engine = re, play_type = "manual",
		update = function() updates = updates + 1 end,
		hasResult = function() return false end,
	}
	local interactor = setmetatable({
		loaded = true, load_generation = 0, gameplay_session = session,
		game = {
			rhythm_engine = re, global_timer = {getTime = function() return 10 end},
			pauseModel = {update = function() end}, windowModel = {setVsyncOnSelect = function() end},
			discordModel = {setPresence = function() end}, multiplayerModel = {client = {setPlaying = function() end}},
		},
		aim_replay_store = {save = function() saves = saves + 1 return "local.json" end},
		score_saver = {saveScore = function() error("must not save/submit an Aim score") end},
	}, {__index = GameplayInteractor})
	interactor:update()
	t:eq(updates, 0)
	interactor:update(true)
	t:eq(updates, 1)
	interactor:unloadGameplay()
	t:eq(saves, 1)
	t:eq(interactor.loaded, false)
end

---@param t testing.T
function test.aim_replay_preparation_keeps_replay_base_contract(t)
	local source = ReplayBase()
	source.rate = 2
	local interactor = setmetatable({game = {replayBase = source}, aim_replay = {rate = 1.5}}, {__index = GameplayInteractor})
	local copy = interactor:getPreparationBase()
	local exported = ReplayBase()
	t:has_not_error(function() copy:exportReplayBase(exported) end)
	t:eq(source.rate, 2)
	t:eq(exported.rate, 1.5)
end

return test
