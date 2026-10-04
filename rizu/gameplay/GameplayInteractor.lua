local Objects = require("chart.format.osu.Objects")
local ReplayBase = require("sea.replays.ReplayBase")
local table_util = require("table_util")
local SdvxInput = require("rizu.gameplay.sdvx.Input")
local TaikoInput = require("rizu.gameplay.taiko.Input")
local CatchInput = require("rizu.gameplay.catch.Input")
local AimInput = require("rizu.gameplay.aim.Input")
local AimReplayStore = require("rizu.gameplay.aim.ReplayStore")
local class = require("class")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local GameplayTimings = require("rizu.gameplay.GameplayTimings")
local RhythmEngineLoader = require("rizu.gameplay.RhythmEngineLoader")
local InputBinder = require("rizu.input.InputBinder")
local KeyPhysicInputEvent = require("rizu.input.KeyPhysicInputEvent")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ScoreSaver = require("rizu.gameplay.ScoreSaver")
local IidxResourcePaths = require("rizu.library.iidx.ResourcePaths")
local Settings = require("rizu.config.Settings")
local Playfield = require("rizu.gameplay.Playfield")
local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")

---@class rizu.GameplayInteractor
---@field playfield rizu.gameplay.Playfield
---@field load_state "empty"|"loading"|"ready"|"failed"
---@field load_error string?
---@field replay_base sea.ReplayBase?
---@operator call: rizu.GameplayInteractor
local GameplayInteractor = class()

---@param game sphere.GameController
function GameplayInteractor:new(game)
	self.game = game
	self.replaying = false
	self.autoplay = false
	self.audio_disabled = false
	self.load_generation = 0
	self.load_state = "empty"
	self.playfield = Playfield(game)
	self.sdvx_replay_store = AimReplayStore(game.fs, "sdvx")
	self.taiko_replay_store = AimReplayStore(game.fs, "taiko")
	self.catch_replay_store = AimReplayStore(game.fs, "catch")
	self.aim_replay_store = AimReplayStore(game.fs)

	self.score_saver = ScoreSaver(
		game.fs,
		game.persistence.library,
		game.persistence.configModel,
		game.seaClient,
		game.replayBase,
		game.computeContext
	)
end

---@param chart chart.Chart
---@return string inputMode
function GameplayInteractor.getInputMode(chart)
	return tostring(chart.inputMode)
end

---@param chartview table
---@return string[]
function GameplayInteractor:getResourcePaths(chartview)
	local paths = {chartview.location_dir}
	local movie_path = IidxResourcePaths.getMoviePath(chartview, self.game.fs)
	if movie_path then
		table.insert(paths, movie_path)
	end
	table.insert(paths, "userdata/hitsounds")
	table.insert(paths, "userdata/hitsounds/midi")
	return paths
end

---@param paths string[]
function GameplayInteractor:loadFileFinderPaths(paths)
	local fileFinder = self.game.fileFinder
	fileFinder:reset()
	for _, path in ipairs(paths) do
		fileFinder:addPath(path)
	end
end

---@return sea.ReplayBase
function GameplayInteractor:getPreparationBase()
	if self.replay_base then
		return self.replay_base
	end
	if not self.aim_replay then
		return self.game.replayBase
	end
	local base = ReplayBase()
	base:importReplayBase(self.game.replayBase)
	base.rate = self.aim_replay.rate
	base.rate_type = "linear"
	base.modifiers = {}
	base.columns_order = nil
	base.tap_only = false
	return base
end

---@param chartview table
---@return boolean loaded
function GameplayInteractor:loadGameplayAsync(chartview)
	if not self.replaying then
		self.replay_base = nil
	end

	local generation = self.load_generation + 1
	self.load_generation = self.load_generation + 1
	self.playfield:unload()
	self.load_state = "loading"
	self.load_error = nil
	local ok, loaded = xpcall(self.prepareGameplayAsync, debug.traceback, self, chartview)
	if generation ~= self.load_generation then
		if not ok then print("Discarded gameplay load error: " .. tostring(loaded)) end
		return false
	end
	if not ok then
		self.playfield:unload()
		self:unloadVolume()
		local engine = self.game.rhythm_engine
		if engine then
			engine:unloadAudio()
			if engine.bga_engine then engine.bga_engine:unload() end
		end
		self.loaded = false
		self.load_state = "failed"
		self.load_error = tostring(loaded)
		error(loaded)
	end
	self.load_state = loaded and "ready" or "empty"
	return loaded
end

---@param chartview table
---@return boolean
function GameplayInteractor:prepareGameplayAsync(chartview)
	local game = self.game
	local load_generation = self.load_generation
	self.loaded = false

	game.previewModel:stop()

	local gameplay_chart = GameplayChart(game.settings, game.fs, chartview)
	local data, context = gameplay_chart:prepareAsync()
	if load_generation ~= self.load_generation then return false end

	local preparation_base = self:getPreparationBase()
	local compute_result = gameplay_chart:computeAsync(preparation_base, data, context)
	if load_generation ~= self.load_generation then
		return false
	end
	if not gameplay_chart:applyComputedAsync(preparation_base, game.computeContext, compute_result, function()
			return load_generation ~= self.load_generation
		end) then
		return false
	end

	local chart = assert(game.computeContext.chart)
	local chartmeta = assert(game.computeContext.chartmeta)
	assert(chartmeta.mode ~= "sdvx" or not self.replaying or self.aim_replay and self.aim_replay.format == "rizu-sdvx-1",
		"Legacy KSH column replays cannot be played with native SDVX rules.")
	assert(chartmeta.mode ~= "taiko" or not self.replaying or self.aim_replay and self.aim_replay.format == "rizu-taiko-1",
		"Legacy 2K replays cannot be played with native Taiko rules.")
	if self.aim_replay then
		if self.aim_replay.format == "rizu-aim-sliders-1" then
			for _, object in ipairs(Objects.get(chart, "osu")) do
				assert(object.kind ~= "spinner", "Incompatible pre-spinner Aim replay.")
			end
		end
		if self.aim_replay.format == "rizu-aim-circles-1" then
			for _, object in ipairs(Objects.get(chart, "osu")) do
				assert(object.kind == "circle", "Incompatible circle-only Aim replay.")
			end
		end
		assert((chartmeta.mode ~= "mania") and self.aim_replay.hash == chartmeta.hash and self.aim_replay.index == chartmeta.index,
			"Aim replay does not match the selected chart.")
		assert((self.aim_replay.format == "rizu-sdvx-1") == (chartmeta.mode == "sdvx"), "Replay mode does not match chart.")
		assert((self.aim_replay.format == "rizu-taiko-1") == (chartmeta.mode == "taiko"), "Replay mode does not match chart.")
		assert((self.aim_replay.format == "rizu-catch-1") == (chartmeta.mode == "catch"), "Replay mode does not match chart.")
	end

	if not self.replaying and chartmeta.mode == "mania" then
		GameplayTimings(game.settings, chartmeta):apply(game.replayBase)
	end

	local input_mode = GameplayInteractor.getInputMode(chart)
	---@type string[]
	local paths
	if chartmeta.mode ~= "mania" then
		assert(not game.multiplayerModel.client:isInRoom(), "Experimental modes are not available in multiplayer.")
		paths = {chartview.location_dir, "userdata/hitsounds", "resources/aim/hitsounds"}
		self.playfield:clearManiaSkin()
	else
		paths = self:getResourcePaths(chartview)
	end
	---@diagnostic disable-next-line: no-unknown
	self.noteSkin = nil
	self:loadFileFinderPaths(paths)

	local resource_future = game.resource_loader:startLoadAsync(chart.resources, paths)
	local snapshot = game.resource_loader:waitLoadAsync(resource_future)
	if load_generation ~= self.load_generation then return false end
	game.resource_loader:applySnapshot(snapshot)

	self:load(self.autoplay)
	if load_generation ~= self.load_generation then return false end
	self.playfield:load()
	if load_generation ~= self.load_generation then return false end

	local input_binder = InputBinder(game.configModel.configs.input, input_mode)
	self.input_binder = input_binder

	game.pauseModel:load()

	game.multiplayerModel.client:setPlaying(chartmeta.mode == "mania")

	game.windowModel:setVsyncOnSelect(false)
	self:play()

	self.loaded = true
	return true
end

---@param autoplay boolean?
function GameplayInteractor:load(autoplay)
	local game = self.game

	self:unloadVolume()
	game:recreateRhythmEngine()
	game.rhythm_engine.aim_stacking = not self.aim_replay or self.aim_replay.format == "rizu-aim-stacking-1" or self.aim_replay.format == "rizu-aim-tracking-1"
	game.rhythm_engine.aim_tracking = not self.aim_replay or self.aim_replay.format == "rizu-aim-tracking-1"

	local replay_base = self.replay_base or game.replayBase
	if self.aim_replay then
		replay_base = table_util.copy(replay_base)
		replay_base.rate = self.aim_replay.rate
	end
	local loader = RhythmEngineLoader(
		replay_base,
		game.computeContext,
		game.settings,
		game.resource_loader.resources,
		game.resource_loader.file_paths
	)
	loader:setAudioEnabled(not self.audio_disabled)
	loader:load(game.rhythm_engine)
	game.offsetController:setRhythmEngine(game.rhythm_engine)
	self:loadVolume()

	self.gameplay_session = GameplaySession(game.rhythm_engine)
	self.sdvx_input = game.rhythm_engine.sdvx_rules and SdvxInput() or nil
	self.taiko_input = game.rhythm_engine.taiko_rules ~= nil
	self.catch_input = game.rhythm_engine.catch_rules ~= nil
	self.aim_input = game.rhythm_engine.aim_rules and AimInput() or nil
	self.aim_saved = false
	self.aim_status = nil
	self.aim_complete = false
	if game.rhythm_engine.aim_rules or game.rhythm_engine.catch_rules or game.rhythm_engine.taiko_rules or game.rhythm_engine.sdvx_rules then
		if self.aim_replay then
			game.rhythm_engine:setRate(self.aim_replay.rate)
		end
	end

	local play_type = "manual"
	if self.replaying then
		play_type = "replay"
	elseif autoplay then
		play_type = "auto"
	end
	
	self.gameplay_session:setPlayType(play_type)
	if play_type == "replay" and self.replay_frames then
		self.gameplay_session:setReplayFrames(self.replay_frames)
	end

	game.rhythm_engine:setGlobalTime(game.global_timer:getTime())
end

function GameplayInteractor:updateVolume()
	local settings = self.game.settings
	local keys = Settings.keys.audio
	local format_key = keys.volume_keysounds_format[self.game.rhythm_engine.chartmeta.format]
	local format_volume = format_key and settings:getNumber(format_key) or 1
	self.game.rhythm_engine:setVolume({
		master = settings:getNumber(keys.volume_master),
		music = settings:getNumber(keys.volume_music),
		keysounds = settings:getNumber(keys.volume_keysounds) * format_volume,
	})
end

function GameplayInteractor:loadVolume()
	local settings = self.game.settings
	local keys = Settings.keys.audio
	local format_key = keys.volume_keysounds_format[self.game.rhythm_engine.chartmeta.format]
	local update_volume = function()
		self:updateVolume()
	end
	self.unsubscribe_volume = {
		settings:subscribeNumber(keys.volume_master, update_volume),
		settings:subscribeNumber(keys.volume_music, update_volume),
		settings:subscribeNumber(keys.volume_keysounds, update_volume),
	}
	if format_key then
		table.insert(self.unsubscribe_volume, settings:subscribeNumber(format_key, update_volume))
	end
	self:updateVolume()
end

function GameplayInteractor:unloadVolume()
	if not self.unsubscribe_volume then
		return
	end
	for _, unsubscribe in ipairs(self.unsubscribe_volume) do
		unsubscribe()
	end
	self.unsubscribe_volume = nil
end

---@param replayBase sea.ReplayBase?
function GameplayInteractor:setReplayBase(replayBase)
	self.replay_base = replayBase
end

---@param frames rizu.ReplayFrame[]
function GameplayInteractor:setReplayFrames(frames)
	self.replay_frames = frames
	if self.gameplay_session then
		self.gameplay_session:setReplayFrames(frames)
	end
end

---Safe to call before loading or repeatedly; callers do not inspect lifecycle state.
function GameplayInteractor:unloadGameplay()
	if self.load_state == "empty" and not self.loaded then return end
	local was_loaded = self.loaded
	-- Check this before skipping to the end: skip() advances the engine to
	-- infinity so checking after it would make every partial play eligible.
	local should_save_score = was_loaded and self:hasResult() and self:hasReachedScoreSaveTime()
	-- Invalidate loading and disable updates before teardown hooks can yield.
	self.load_generation = self.load_generation + 1
	self.loaded = false
	self.load_state = "empty"
	self.load_error = nil
	if self.playfield then self.playfield:unload() end
	self:unloadVolume()
	if self.playfield then self.playfield:clearManiaSkin() end

	local re = self.game.rhythm_engine
	if re and (re.aim_rules or re.catch_rules or re.taiko_rules or re.sdvx_rules) and was_loaded then
		self:saveAimReplay()
	end
	self.aim_replay = nil
	self.replay_base = nil
	self.replaying = false
	self.autoplay = false
	local game = self.game

	game.windowModel:setVsyncOnSelect(true)
	game.discordModel:setPresence({})
	if was_loaded then self:skip() end

	if game.rhythm_engine then
		game.rhythm_engine:unloadAudio()
		if game.rhythm_engine.bga_engine then
			game.rhythm_engine.bga_engine:unload()
		end
	end

	if should_save_score then
		self:saveScore()
	end
	self.gameplay_session = nil

	game.multiplayerModel.client:setPlaying(false)
end

---@return rizu.gameplay.Playfield?
function GameplayInteractor:getPlayfield()
	if self.loaded and self.load_state == "ready" then return self.playfield end
end

---@return string
function GameplayInteractor:getState() return self.load_state end

---@return string?
function GameplayInteractor:getError() return self.load_error end

---@param dt number
---@param after_inputs boolean?
function GameplayInteractor:update(dt, after_inputs)
	if not self.loaded then
		return
	end

	local game = self.game
	-- Experimental input is timestamped and queued by the UI. Resolve it before deadlines.
	local engine = game.rhythm_engine
	local deferred = engine and (engine.aim_rules or engine.catch_rules or engine.taiko_rules or engine.sdvx_rules)
	if not deferred or after_inputs then
		self.gameplay_session:update(game.global_timer:getTime())
		game.pauseModel:update()
		if game.pauseModel.needRetry then
			self:retry()
		end
	end

	-- The after-input pass resolves gameplay only; skin animation advances once per frame.
	if not after_inputs then
		local playfield = self:getPlayfield()
		if playfield then
			playfield:update(dt)
			playfield:updateBackgroundHud(dt)
			playfield:updateHud(dt)
		end
	end
end

---@param delta number
function GameplayInteractor:increasePlaySpeed(delta)
	local game = self.game

	local keys = Settings.keys.gameplay
	local speed_type = game.settings:getChoice(keys.speed_type)
	local speed = ScrollSpeed.increase(speed_type, game.settings:getNumber(keys.speed), delta)
	game.settings:setNumber(keys.speed, speed)
	game.rhythm_engine:setVisualRate(speed, game.settings:getBoolean(keys.scale_speed))
end

---@return boolean
function GameplayInteractor:hasResult()
	return self.gameplay_session and self.gameplay_session:hasResult() or false
end

---@return boolean
function GameplayInteractor:hasReachedScoreSaveTime()
	local re = self.game.rhythm_engine
	if not re then
		return false
	end

	local time = re:getTime()
	local chartdiff = re.chartdiff
	local last_note_time = chartdiff and chartdiff.start_time + chartdiff.duration
	local progress = re.play_progress
	local chart_end_time = progress and progress.start_time + progress.duration

	return last_note_time and time >= last_note_time
		or chart_end_time and time >= chart_end_time
		or false
end

function GameplayInteractor:saveScore()
	assert(not self.game.rhythm_engine.aim_rules and not self.game.rhythm_engine.catch_rules and not self.game.rhythm_engine.taiko_rules and not self.game.rhythm_engine.sdvx_rules, "Experimental modes cannot save or submit scores")
	self.score_saver:saveScore(self.gameplay_session)
end

function GameplayInteractor:play()
	self.gameplay_session:play(true)
	-- self:discordPlay()
end

function GameplayInteractor:pause()
	self.gameplay_session:pause()
	-- self:discordPause()
end

function GameplayInteractor:retry()
	local game = self.game
	local replayBase = game.replayBase

	game.pauseModel:load()

	if self.playfield then self.playfield:unload() end
	local ok, err = xpcall(function()
		self:load(self.autoplay)
		if self.playfield then self.playfield:load() end
	end, debug.traceback)
	if not ok then
		if self.playfield then self.playfield:unload() end
		self.loaded = false
		self.load_state = "failed"
		self.load_error = tostring(err)
		error(err)
	end

	game.rhythm_engine:setTimings(replayBase.timings, replayBase.subtimings)
	self:play()
end

function GameplayInteractor:skipIntro()
	self.gameplay_session:skipIntro()
end

function GameplayInteractor:skip()
	if self.game.rhythm_engine then
		self.game.rhythm_engine:setTime(math.huge)
	end
end

---@param state "play"|"pause"|"retry"
function GameplayInteractor:changePlayState(state)
	local game = self.game
	if game.multiplayerModel.client:isInRoom() then
		return
	end

	-- if state == "play" then
	-- 	self:discordPlay()
	-- elseif state == "pause" then
	-- 	self:discordPause()
	-- end

	game.pauseModel:changePlayState(state)
end

---@param event table
function GameplayInteractor:receive(event)
	local game = self.game
	local physic_event = KeyPhysicInputEvent.fromInputChangedEvent(event)
	if self.sdvx_input then
		if self.aim_complete then return end
		local virtual_event = self.sdvx_input:transform(event)
		if virtual_event then self.gameplay_session:receive(virtual_event, event.time) end
		return
	end
	if self.taiko_input then
		if self.aim_complete then return end
		local virtual_event = TaikoInput.transform(event)
		if virtual_event then self.gameplay_session:receive(virtual_event, event.time) end
		return
	end
	if self.catch_input then
		if self.aim_complete then return end
		local virtual_event = CatchInput.transform(event)
		if virtual_event then self.gameplay_session:receive(virtual_event, event.time) end
		return
	end
	if self.aim_input then
		if self.aim_complete then return end
		local virtual_event = self.aim_input:transform(event)
		if virtual_event then
			self.gameplay_session:receive(virtual_event, event.time or game.global_timer:getTime())
		end
		return
	end
	if physic_event then
		local virtual_event = self.input_binder:transform(physic_event)
		if virtual_event then
			self.gameplay_session:receive(virtual_event, game.global_timer:getTime())
		end
	end
end

---@param x number
---@param y number
---@param time number
function GameplayInteractor:aimPointer(x, y, time)
	if self.aim_input and self.loaded and not self.aim_complete then
		self.gameplay_session:receive(self.aim_input:move(x, y), time)
	end
end

---@return string?
function GameplayInteractor:saveAimReplay()
	local session = self.gameplay_session
	if not session or not (session.rhythm_engine.aim_rules or session.rhythm_engine.catch_rules or session.rhythm_engine.taiko_rules or session.rhythm_engine.sdvx_rules) or session.play_type ~= "manual" or self.aim_saved then
		return
	end
	local store = session.rhythm_engine.sdvx_rules and self.sdvx_replay_store or session.rhythm_engine.taiko_rules and self.taiko_replay_store or session.rhythm_engine.catch_rules and self.catch_replay_store or self.aim_replay_store
	local ok, path = pcall(store.save, store, session)
	self.aim_saved = ok
	self.aim_status = ok and ("Replay saved: " .. path) or ("Replay save failed: " .. tostring(path))
	return self.aim_status
end

---@param hash string
---@param index integer
---@param catch boolean|"taiko"|"sdvx"? Legacy true selects Catch; strings select another experimental mode.
---@return boolean
---@return string?
function GameplayInteractor:loadAimReplay(hash, index, catch)
	local store = catch == "sdvx" and self.sdvx_replay_store or catch == "taiko" and self.taiko_replay_store or catch and self.catch_replay_store or self.aim_replay_store
	local ok, replay, frames = pcall(store.load, store, hash, index)
	if not ok then
		return false, tostring(replay)
	end
	self.aim_replay = replay
	self.replay_frames = frames
	self.replaying = true
	self.autoplay = false
	return true
end

return GameplayInteractor
