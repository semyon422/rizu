local Gamemodes = require("rizu.gameplay.Gamemodes")
local ReplayStore = require("rizu.gameplay.ReplayStore")
local class = require("class")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local GameplayTimings = require("rizu.gameplay.GameplayTimings")
local RhythmEngineLoader = require("rizu.gameplay.RhythmEngineLoader")
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
---@field replay_base (rizu.gameplay.ReplayBase|sea.ReplayBase)? Of the replay being watched.
---@field replay_chart {hash: string, index: integer}? Chart a local replay was loaded for.
---@field replay_stores {[sea.Gamemode]: rizu.gameplay.ReplayStore} For gamemodes that do not save scores.
---@field complete boolean? The attempt ended and waits on its summary.
---@field gamemode rizu.gameplay.Gamemode Of the loaded chart.
---@field input rizu.gameplay.GamemodeInput
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
	self.replay_stores = {}
	for mode, gamemode in pairs(Gamemodes) do
		if not gamemode.saves_scores then
			self.replay_stores[mode] = ReplayStore(game.fs, gamemode.ReplayBase)
		end
	end

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

---The directory of the skin selected for this play, whose sounds can stand in for the chart's.
---@param gamemode rizu.gameplay.Gamemode
---@param input_mode string
---@return string?
function GameplayInteractor:getSkinDirectory(gamemode, input_mode)
	local registry = self.game.skinRegistry
	local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
	-- An osu! skin picked for a non-mania mode is stored under the osu/ key.
	local osu_path = skin_paths["osu/" .. input_mode]
	local skin = osu_path and registry:getOsuSkin(osu_path)
		or registry:getSkinForInputMode(gamemode.name, input_mode, skin_paths[gamemode.name .. "/" .. input_mode])
	return skin and skin.directory_path
end

---@param chartview table
---@param gamemode rizu.gameplay.Gamemode
---@param input_mode string
---@return string[]
function GameplayInteractor:getResourcePaths(chartview, gamemode, input_mode)
	local paths = {chartview.location_dir}
	local skin_directory = self:getSkinDirectory(gamemode, input_mode)
	if skin_directory then
		local top_priority = self.game.settings:getBoolean(Settings.keys.gameplay.skin_resources_top_priority)
		table.insert(paths, top_priority and 1 or 2, skin_directory)
	end
	local movie_path = IidxResourcePaths.getMoviePath(chartview, self.game.fs)
	if movie_path then
		table.insert(paths, movie_path)
	end
	for _, path in ipairs(gamemode.resource_paths) do
		table.insert(paths, path)
	end
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

---The watched replay's base, or what is selected for a new play. May belong to another
---gamemode than the chart: each gamemode takes from it what it shares.
---@return rizu.gameplay.ReplayBase|sea.ReplayBase
function GameplayInteractor:getPreparationBase()
	return self.replay_base or self.game.replayBase
end

---@param chartview table
---@return boolean loaded
function GameplayInteractor:loadGameplayAsync(chartview)
	if not self.replaying then
		self.replay_base = nil
		self.replay_chart = nil
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
	local gamemode = Gamemodes[chartmeta.mode]
	local replay_chart = self.replay_chart
	assert(not self.replaying or gamemode.saves_scores or gamemode.ReplayBase * preparation_base,
		"This replay was recorded in another gamemode.")
	assert(not replay_chart or not gamemode.saves_scores
		and replay_chart.hash == chartmeta.hash and replay_chart.index == chartmeta.index,
		"Local replay does not match the selected chart.")

	if not self.replaying and chartmeta.mode == "mania" then
		GameplayTimings(game.settings, chartmeta):apply(game.replayBase)
	end

	assert(gamemode.saves_scores or not game.multiplayerModel.client:isInRoom(),
		"Experimental modes are not available in multiplayer.")
	local paths = self:getResourcePaths(chartview, gamemode, GameplayInteractor.getInputMode(chart))
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

	game.pauseModel:load()

	game.multiplayerModel.client:setPlaying(gamemode.saves_scores)

	game.windowModel:setVsyncOnSelect(false)
	self:play()

	self.loaded = true
	return true
end

---@param autoplay boolean?
function GameplayInteractor:load(autoplay)
	local game = self.game

	self:unloadVolume()
	local mode = game.computeContext.chartmeta.mode
	local gamemode = Gamemodes[mode]
	self.gamemode = gamemode
	local replay_base = gamemode:getReplayBase(self:getPreparationBase())
	game:recreateRhythmEngine(mode, replay_base)

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
	self.input = gamemode:createInput(
		game.configModel.configs.input,
		GameplayInteractor.getInputMode(game.computeContext.chart)
	)
	self.replay_saved = false
	self.replay_status = nil
	self.complete = false

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
	if self.playfield then self.playfield:clearSkin() end

	if was_loaded then
		self:saveLocalReplay()
	end
	self.replay_base = nil
	self.replay_chart = nil
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
	-- Deferred input is timestamped and queued by the UI. Resolve it before deadlines.
	if not self.gamemode.deferred_input or after_inputs then
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
	if self.complete then return end
	local virtual_event = self.input:transform(event)
	if virtual_event then
		local time = self.gamemode.deferred_input and event.time or self.game.global_timer:getTime()
		self.gameplay_session:receive(virtual_event, time)
	end
end

---@param x number
---@param y number
---@param time number
function GameplayInteractor:movePointer(x, y, time)
	if self.loaded and not self.complete and self.input.move then
		self.gameplay_session:receive(self.input:move(x, y), time)
	end
end

---Keeps the latest manual attempt of a gamemode that does not save scores.
---@return string? status
function GameplayInteractor:saveLocalReplay()
	local session = self.gameplay_session
	local engine = self.game.rhythm_engine
	local store = session and engine and self.replay_stores[engine.mode]
	if not store or session.play_type ~= "manual" or self.replay_saved then
		return
	end
	local ok, path = pcall(store.save, store, session)
	self.replay_saved = ok
	self.replay_status = ok and ("Replay saved: " .. path) or ("Replay save failed: " .. tostring(path))
	return self.replay_status
end

---@param hash string
---@param index integer
---@param mode sea.Gamemode
---@return boolean
---@return string?
function GameplayInteractor:loadLocalReplay(hash, index, mode)
	local store = self.replay_stores[mode]
	if not store then
		return false, "This gamemode has no local replays."
	end
	local ok, base, frames = pcall(store.load, store, hash, index)
	if not ok then
		return false, tostring(base)
	end
	self.replay_base = base
	self.replay_chart = {hash = hash, index = index}
	self.replay_frames = frames
	self.replaying = true
	self.autoplay = false
	return true
end

return GameplayInteractor
