local ReplayBase = require("sea.replays.ReplayBase")
local table_util = require("table_util")
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
local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")

---@class rizu.GameplayInteractor
---@operator call: rizu.GameplayInteractor
local GameplayInteractor = class()

---@param game sphere.GameController
function GameplayInteractor:new(game)
	self.game = game
	self.replaying = false
	self.autoplay = false
	self.audio_disabled = false
	self.load_generation = 0
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

---@param noteSkin table
---@param chartview table
---@return string[]
function GameplayInteractor:getResourcePaths(noteSkin, chartview)
	local paths = {}
	if self.game.settings:getBoolean(Settings.keys.gameplay.skin_resources_top_priority) then
		table.insert(paths, noteSkin.directoryPath)
		table.insert(paths, chartview.location_dir)
	else
		table.insert(paths, chartview.location_dir)
		table.insert(paths, noteSkin.directoryPath)
	end
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
	local game = self.game
	self.load_generation = self.load_generation + 1
	local load_generation = self.load_generation
	self.loaded = false

	game.previewModel:stop()

	local gameplay_chart = GameplayChart(game.settings, game.fs, chartview)
	local data, context = gameplay_chart:prepareAsync()

	local preparation_base = self:getPreparationBase()
	local compute_result = gameplay_chart:computeAsync(preparation_base, data, context)
	if load_generation ~= self.load_generation then
		return false
	end
	gameplay_chart:applyComputed(preparation_base, game.computeContext, compute_result)

	local chart = assert(game.computeContext.chart)
	local chartmeta = assert(game.computeContext.chartmeta)
	if self.aim_replay then
		if self.aim_replay.format == "rizu-aim-sliders-1" then
			for _, object in ipairs(assert(chart.aim).objects) do
				assert(object.kind ~= "spinner", "Incompatible pre-spinner Aim replay.")
			end
		end
		if self.aim_replay.format == "rizu-aim-circles-1" then
			for _, object in ipairs(assert(chart.aim).objects) do
				assert(object.kind == "circle", "Incompatible circle-only Aim replay.")
			end
		end
		assert((chart.aim or chart.catch) and self.aim_replay.hash == chartmeta.hash and self.aim_replay.index == chartmeta.index,
			"Aim replay does not match the selected chart.")
		assert((self.aim_replay.format == "rizu-catch-1") == (chart.catch ~= nil), "Replay mode does not match chart.")
	end

	if not self.replaying and not chart.aim and not chart.catch then
		GameplayTimings(game.settings, chartmeta):apply(game.replayBase)
	end

	local input_mode = GameplayInteractor.getInputMode(chart)
	---@type string[]
	local paths
	if chart.aim or chart.catch then
		assert(not game.multiplayerModel.client:isInRoom(), "Experimental modes are not available in multiplayer.")
		paths = {chartview.location_dir, "userdata/hitsounds", "resources/aim/hitsounds"}
		self.noteSkin = nil
	else
		local noteSkin = game.noteSkinModel:loadNoteSkin(input_mode)
		noteSkin:loadData()
		self.noteSkin = noteSkin
		paths = self:getResourcePaths(noteSkin, chartview)
	end
	self:loadFileFinderPaths(paths)

	local resource_future = game.resource_loader:startLoadAsync(chart.resources, paths)

	local snapshot = game.resource_loader:waitLoadAsync(resource_future)
	if load_generation ~= self.load_generation then
		return false
	end
	game.resource_loader:applySnapshot(snapshot)

	self:load(self.autoplay)

	local input_binder = InputBinder(game.configModel.configs.input, input_mode)
	self.input_binder = input_binder

	game.pauseModel:load()

	game.multiplayerModel.client:setPlaying(not chart.aim and not chart.catch)
	if not chart.aim and not chart.catch then
		game.offsetController:updateOffsets()
	end

	game.windowModel:setVsyncOnSelect(false)
	self:play()

	self.loaded = true
	return true
end

---@param autoplay boolean?
function GameplayInteractor:load(autoplay)
	local game = self.game

	game:recreateRhythmEngine()
	game.rhythm_engine.aim_stacking = not self.aim_replay or self.aim_replay.format == "rizu-aim-stacking-1" or self.aim_replay.format == "rizu-aim-tracking-1"
	game.rhythm_engine.aim_tracking = not self.aim_replay or self.aim_replay.format == "rizu-aim-tracking-1"

	local replay_base = game.replayBase
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

	self.gameplay_session = GameplaySession(game.rhythm_engine)
	self.catch_input = game.rhythm_engine.catch_rules ~= nil
	self.aim_input = game.rhythm_engine.aim_rules and AimInput() or nil
	self.aim_saved = false
	self.aim_status = nil
	self.aim_complete = false
	game.offsetController.rhythm_engine = game.rhythm_engine
	if game.rhythm_engine.aim_rules or game.rhythm_engine.catch_rules then
		game.offsetController:updateOffsets()
		if self.aim_replay then
			game.rhythm_engine:setInputOffset(self.aim_replay.input_offset)
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

---@param frames rizu.ReplayFrame[]
function GameplayInteractor:setReplayFrames(frames)
	self.replay_frames = frames
	if self.gameplay_session then
		self.gameplay_session:setReplayFrames(frames)
	end
end

function GameplayInteractor:unloadGameplay()
	local re = self.game.rhythm_engine
	if re and (re.aim_rules or re.catch_rules) and self.loaded then
		self:saveAimReplay()
	end
	self.aim_replay = nil
	self.load_generation = self.load_generation + 1
	self.loaded = false
	self.replaying = false
	self.autoplay = false
	local game = self.game

	game.windowModel:setVsyncOnSelect(true)
	game.discordModel:setPresence({})
	self:skip()

	if game.rhythm_engine then
		game.rhythm_engine:unloadAudio()
		if game.rhythm_engine.bga_engine then
			game.rhythm_engine.bga_engine:unload()
		end
	end

	if self:hasResult() then
		self:saveScore()
	end

	game.multiplayerModel.client:setPlaying(false)
end

---@param after_inputs boolean?
function GameplayInteractor:update(after_inputs)
	if not self.loaded then
		return
	end

	local game = self.game
	-- Experimental input is timestamped and queued by the UI. Resolve it before deadlines.
	if game.rhythm_engine and (game.rhythm_engine.aim_rules or game.rhythm_engine.catch_rules) and not after_inputs then
		return
	end
	self.gameplay_session:update(game.global_timer:getTime())
	game.pauseModel:update()
	if game.pauseModel.needRetry then
		self:retry()
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

function GameplayInteractor:saveScore()
	assert(not self.game.rhythm_engine.aim_rules and not self.game.rhythm_engine.catch_rules, "Experimental modes cannot save or submit scores")
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

	self:load(self.autoplay)

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
	if not session or not (session.rhythm_engine.aim_rules or session.rhythm_engine.catch_rules) or session.play_type ~= "manual" or self.aim_saved then
		return
	end
	local store = session.rhythm_engine.catch_rules and self.catch_replay_store or self.aim_replay_store
	local ok, path = pcall(store.save, store, session)
	self.aim_saved = ok
	self.aim_status = ok and ("Replay saved: " .. path) or ("Replay save failed: " .. tostring(path))
	return self.aim_status
end

---@param hash string
---@param index integer
---@param catch boolean?
---@return boolean
---@return string?
function GameplayInteractor:loadAimReplay(hash, index, catch)
	local store = catch and self.catch_replay_store or self.aim_replay_store
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
