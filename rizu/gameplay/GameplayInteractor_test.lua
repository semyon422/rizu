local ReplayBase = require("sea.replays.ReplayBase")
local InputMode = require("chart.core.InputMode")
local GameplayInteractor = require("rizu.gameplay.GameplayInteractor")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local RhythmEngine = require("rizu.gameplay.mania.Engine")
local ManiaInput = require("rizu.gameplay.mania.Input")
local Gamemodes = require("rizu.gameplay.Gamemodes")
local ReplayStore = require("rizu.gameplay.ReplayStore")
local ReplayRecorder = require("rizu.engine.replay.ReplayRecorder")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
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
function test.selected_skin_directory_joins_resource_paths_by_priority(t)
	local osu_skin = {path = "skins/osu", format = "osu"}
	local mania_skin = {path = "skins/mania", format = "lua"}
	local builtin_skin = {path = "builtin/mania", format = "builtin"}
	local top_priority = false
	local interactor = {
		game = {
			settings = {getBoolean = function() return top_priority end},
			skinRegistry = {
				resolve = function(_, gamemode, input_mode)
					if gamemode == "osu" then return osu_skin end
					return input_mode == "4key" and mania_skin or builtin_skin
				end,
			},
		},
		getSkinDirectory = GameplayInteractor.getSkinDirectory,
	}
	local chartview = {location_dir = "chart"}
	local aim = {name = "osu", resource_paths = {"userdata/hitsounds"}}
	local mania = {name = "mania", resource_paths = {"userdata/hitsounds"}}

	t:tdeq(GameplayInteractor.getResourcePaths(interactor, chartview, aim, "1osu"),
		{"chart", "skins/osu", "userdata/hitsounds"})
	t:tdeq(GameplayInteractor.getResourcePaths(interactor, chartview, mania, "4key"),
		{"chart", "skins/mania", "userdata/hitsounds"})
	t:tdeq(GameplayInteractor.getResourcePaths(interactor, chartview, mania, "7key"),
		{"chart", "userdata/hitsounds"})
	top_priority = true
	t:tdeq(GameplayInteractor.getResourcePaths(interactor, chartview, aim, "1osu"),
		{"skins/osu", "chart", "userdata/hitsounds"})
end

---@param t testing.T
function test.paused_input_updates_binding(t)
	local session = {receive = function() end}
	local input = ManiaInput({["4key"] = {{{"a", "keyboard", 1}}}}, "4key")
	local interactor = setmetatable({
		game = {global_timer = {getTime = function() return 0 end}},
		gameplay_session = session,
		gamemode = Gamemodes.mania,
		input = input,
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
		gamemode = Gamemodes.mania,
		input = ManiaInput({["4key"] = {
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
		local interactor = setmetatable({gamemode = Gamemodes.mania,
			loaded = true,
			autoplay = true,
			playfield = {
				unload = function() t:eq(attempts, 0) end,
				load = function() t:eq(attempts, 1); t:eq(plays, 0) end,
			},
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
		interactor:update(0.25)
		t:ne(interactor.gameplay_session, session)
		t:eq(attempts, 1)
		t:eq(plays, 1)
		t:eq(pause_model.needRetry, false)
		t:eq(pause_model.state, "play")
		interactor:update(0.25)
		t:eq(attempts, 1)
	end
end

---@param t testing.T
function test.aim_deadlines_wait_for_queued_input_and_score_is_never_saved(t)
	local updates, saves = 0, 0
	local re = {mode = "osu", unloadAudio = function() end, setTime = function() end}
	local session = {
		rhythm_engine = re, play_type = "manual",
		update = function() updates = updates + 1 end,
		hasResult = function() return false end,
	}
	local interactor = setmetatable({
		loaded = true, load_generation = 0, gameplay_session = session, gamemode = Gamemodes.osu,
		game = {
			rhythm_engine = re, global_timer = {getTime = function() return 10 end},
			pauseModel = {update = function() end}, windowModel = {setVsyncOnSelect = function() end},
			discordModel = {setPresence = function() end}, multiplayerModel = {client = {setPlaying = function() end}},
		},
		replay_stores = {osu = {save = function() saves = saves + 1 return "local.json" end}},
		score_saver = {saveScore = function() error("must not save/submit an Aim score") end},
	}, {__index = GameplayInteractor})
	interactor:update(0.25)
	t:eq(updates, 0)
	interactor:update(0.25, true)
	t:eq(updates, 1)
	interactor:unloadGameplay()
	t:eq(saves, 1)
	t:eq(interactor.loaded, false)
end

---@param t testing.T
function test.local_replay_base_replaces_the_selection_without_touching_it(t)
	local source = ReplayBase()
	source.rate = 2
	source.modifiers = {{id = 1}}
	local fs = FakeFilesystem()
	local hash = ("a"):rep(32)
	local interactor = setmetatable({game = {replayBase = source},
		replay_stores = {osu = ReplayStore(fs, Gamemodes.osu.ReplayBase)}}, {__index = GameplayInteractor})
	t:eq(interactor:getPreparationBase(), source)
	-- Mania modifiers do not reach another gamemode: only the rate is shared.
	local selected = Gamemodes.osu:getReplayBase(source)
	t:eq(selected.rate, 2)
	t:eq(selected.modifiers, nil)
	t:eq(Gamemodes.mania:getReplayBase(source), source)

	local recorder = ReplayRecorder()
	recorder:record(0, VirtualInputEvent(1, true, 1, {1, 2}))
	interactor.replay_stores.osu:save({play_type = "manual", replay_recorder = recorder, rhythm_engine = {
		chartmeta = {hash = hash, index = 1}, time_engine = {timer = {rate = 1.5}}}})
	t:eq(interactor:loadLocalReplay(hash, 1, "mania"), false)
	t:eq(interactor:loadLocalReplay(hash, 1, "osu"), true)
	local base = interactor:getPreparationBase()
	t:eq(base.rate, 1.5)
	t:eq(Gamemodes.osu:getReplayBase(base), base)
	t:eq(source.rate, 2)
	-- The worker thread receives plain data and rebuilds the same base from it.
	local data = {}
	base:exportReplayBase(data)
	data.format = "rizu-aim-sliders-1"
	local rebuilt = Gamemodes.osu:createReplayBase(data)
	t:eq(rebuilt.rate, 1.5)
	t:eq(rebuilt:hasStacking(), false)
end

---@param t testing.T
function test.core_runtime_preparation_precedes_playback_and_ui_getter(t)
	local calls = {}
	local engine = {chartmeta = {mode = "mania"}, chart = {inputMode = "4key"}, unloadAudio = function() end}
	local renderer = require("rizu.gameplay.views.PlayfieldRenderer")({})
	renderer.load = function() calls[#calls + 1] = "runtime" end
	local settings = Settings.createConfig(FakeFilesystem())
	local interactor = setmetatable({load_generation = 0, loaded = false,
		game = {rhythm_engine = engine, settings = settings, skinRegistry = {
			resolve = function() return {} end,
			createRenderer = function() return renderer end,
		}, unloadAudio = function() end,
		windowModel = {setVsyncOnSelect = function() end}, discordModel = {setPresence = function() end},
		multiplayerModel = {client = {setPlaying = function() end}}}, mania_renderer = renderer}, {__index = GameplayInteractor})
	interactor.game.gameplayInteractor = interactor
	interactor.playfield = require("rizu.gameplay.Playfield")(interactor.game)
	interactor.prepareGameplayAsync = function(self)
		self.playfield:load()
		calls[#calls + 1] = "play"
		self.loaded = true
		return true
	end
	t:eq(interactor:getPlayfield(), nil)
	t:assert(interactor:loadGameplayAsync({}))
	t:tdeq(calls, {"runtime", "play"})
	t:eq(interactor:getPlayfield(), interactor.playfield)
	interactor.playfield:load() -- UI entry must not duplicate runtime/HUD loading.
	t:eq(#calls, 2)
	interactor.playfield:unload()
end

---@param t testing.T
function test.gameplay_preparation_failure_is_not_ready_and_tears_down(t)
	local interactor = setmetatable({load_generation = 0, game = {},
		playfield = {unload = function() end, clearSkin = function() end},
		prepareGameplayAsync = function() error("runtime failed before play") end}, {__index = GameplayInteractor})
	t:assert(not pcall(interactor.loadGameplayAsync, interactor, {}))
	t:eq(interactor:getState(), "failed")
	t:eq(interactor:getPlayfield(), nil)
	t:assert(interactor:getError():find("before play", 1, true))
end

---@param t testing.T
function test.update_advances_ready_playfield_after_session_and_pause(t)
	local calls = {} ---@type string[]
	local interactor = setmetatable({gamemode = Gamemodes.mania, loaded = false, load_state = "loading", playfield = {
		update = function(_, dt) calls[#calls + 1] = "runtime"; t:eq(dt, 0.25) end,
		updateBackgroundHud = function(_, dt) calls[#calls + 1] = "background"; t:eq(dt, 0.25) end,
		updateHud = function(_, dt) calls[#calls + 1] = "hud"; t:eq(dt, 0.25) end,
	}, gameplay_session = {update = function() calls[#calls + 1] = "session" end}, game = {
		global_timer = {getTime = function() return 10 end},
		pauseModel = {update = function() calls[#calls + 1] = "pause" end},
	}}, {__index = GameplayInteractor})
	interactor:update(0.25)
	t:eq(#calls, 0)
	interactor.loaded = true
	interactor:update(0.25)
	t:tdeq(calls, {"session", "pause"})
	interactor.load_state = "ready"
	interactor:update(0.25)
	t:tdeq(calls, {"session", "pause", "session", "pause", "runtime", "background", "hud"})
end

---@param t testing.T
function test.after_input_pass_does_not_update_playfield_twice(t)
	for _, gamemode in ipairs({Gamemodes.osu, Gamemodes.catch, Gamemodes.taiko, Gamemodes.sdvx}) do
		local calls = {} ---@type string[]
		local interactor = setmetatable({loaded = true, load_state = "ready", gamemode = gamemode, playfield = {
			update = function(_, dt) calls[#calls + 1] = "runtime"; t:eq(dt, 0.25) end,
			updateBackgroundHud = function() calls[#calls + 1] = "background" end,
			updateHud = function() calls[#calls + 1] = "hud" end,
		}, gameplay_session = {update = function() calls[#calls + 1] = "session" end}, game = {
			rhythm_engine = {},
			global_timer = {getTime = function() return 10 end},
			pauseModel = {update = function() calls[#calls + 1] = "pause" end},
		}}, {__index = GameplayInteractor})
		interactor:update(0.25)
		t:tdeq(calls, {"runtime", "background", "hud"})
		interactor:update(0.25, true)
		t:tdeq(calls, {"runtime", "background", "hud", "session", "pause"})
	end
end

---@param t testing.T
function test.unload_before_loading_is_a_noop(t)
	local interactor = setmetatable({load_state = "empty", load_generation = 0, game = {}},
		{__index = GameplayInteractor})
	t:has_not_error(function()
		interactor:unloadGameplay()
		interactor:unloadGameplay()
	end)
	t:eq(interactor.load_generation, 0)
end

---@param t testing.T
function test.unload_is_idempotent_for_loading_failed_and_ready_gameplay(t)
	for _, state in ipairs({"loading", "failed", "ready"}) do
		local calls = {playfield = 0, audio = 0, bga = 0, skip = 0, score = 0, playing = 0}
		local session = {hasResult = function() return true end}
		local interactor = setmetatable({load_state = state, loaded = state == "ready", replay_stores = {},
			load_generation = 0, gameplay_session = session,
			game = {
				rhythm_engine = {
					setTime = function() calls.skip = calls.skip + 1 end,
					getTime = function() return 10 end,
					chartdiff = {start_time = 0, duration = 10},
					play_progress = {start_time = 0, duration = 10},
					unloadAudio = function() calls.audio = calls.audio + 1 end,
					bga_engine = {unload = function() calls.bga = calls.bga + 1 end},
				},
				windowModel = {setVsyncOnSelect = function() end},
				discordModel = {setPresence = function() end},
				multiplayerModel = {client = {setPlaying = function(_, playing)
					t:eq(playing, false)
					calls.playing = calls.playing + 1
				end}},
			},
			score_saver = {saveScore = function(_, saved_session)
				t:eq(saved_session, session)
				calls.score = calls.score + 1
			end},
		}, {__index = GameplayInteractor})
		interactor.playfield = {unload = function()
			t:eq(interactor.loaded, false)
			t:eq(interactor.load_generation, 1)
			calls.playfield = calls.playfield + 1
			interactor:unloadGameplay()
		end, clearSkin = function() end}
		interactor:unloadGameplay()
		interactor:unloadGameplay()
		t:eq(calls.playfield, 1)
		t:eq(calls.audio, 1)
		t:eq(calls.bga, 1)
		t:eq(calls.playing, 1)
		t:eq(calls.skip, state == "ready" and 1 or 0)
		t:eq(calls.score, state == "ready" and 1 or 0)
		t:eq(interactor.load_generation, 1)
		t:eq(interactor:getState(), "empty")
		t:eq(interactor.gameplay_session, nil)
		t:eq(interactor:hasResult(), false)
	end
end

---@param t testing.T
function test.partial_play_is_not_saved_until_chart_end(t)
	local function make_interactor(time)
		local saves = 0
		local interactor = setmetatable({load_state = "ready", loaded = true, replay_stores = {},
			load_generation = 0, gameplay_session = {hasResult = function() return true end},
			game = {
				rhythm_engine = {
					getTime = function() return time end,
					chartdiff = {start_time = 2, duration = 6},
					play_progress = {start_time = 2, duration = 8},
					setTime = function() end,
					unloadAudio = function() end,
				},
				windowModel = {setVsyncOnSelect = function() end},
				discordModel = {setPresence = function() end},
				multiplayerModel = {client = {setPlaying = function() end}},
			},
			score_saver = {saveScore = function() saves = saves + 1 end},
		}, {__index = GameplayInteractor})
		interactor.playfield = {unload = function() end, clearSkin = function() end}
		return interactor, function() return saves end
	end

	local partial, partial_saves = make_interactor(7.9)
	partial:unloadGameplay()
	t:eq(partial_saves(), 0)

	local after_last_note, after_last_note_saves = make_interactor(8.1)
	after_last_note:unloadGameplay()
	t:eq(after_last_note_saves(), 1)

	local complete, complete_saves = make_interactor(10)
	complete:unloadGameplay()
	t:eq(complete_saves(), 1)
end

return test
