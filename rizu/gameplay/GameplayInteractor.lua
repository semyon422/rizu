local class = require("class")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local GameplayTimings = require("rizu.gameplay.GameplayTimings")
local RhythmEngineLoader = require("rizu.gameplay.RhythmEngineLoader")
local InputBinder = require("rizu.input.InputBinder")
local KeyPhysicInputEvent = require("rizu.input.KeyPhysicInputEvent")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ScoreSaver = require("rizu.gameplay.ScoreSaver")
local IidxResourcePaths = require("rizu.library.iidx.ResourcePaths")

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
	if self.game.configModel.configs.settings.gameplay.skin_resources_top_priority then
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

---@param chartview table
---@return boolean loaded
function GameplayInteractor:loadGameplayAsync(chartview)
	local game = self.game
	self.load_generation = self.load_generation + 1
	local load_generation = self.load_generation
	self.loaded = false

	game.previewModel:stop()

	local gameplay_chart = GameplayChart(game.configModel.configs.settings, game.fs, chartview)
	local data, context = gameplay_chart:prepareAsync()

	local compute_result = gameplay_chart:computeAsync(game.replayBase, data, context)
	if load_generation ~= self.load_generation then
		return false
	end
	gameplay_chart:applyComputed(game.replayBase, game.computeContext, compute_result)

	local chart = assert(game.computeContext.chart)
	local chartmeta = assert(game.computeContext.chartmeta)

	if not self.replaying then
		GameplayTimings(game.configModel.configs.settings, chartmeta):apply(game.replayBase)
	end

	local input_mode = GameplayInteractor.getInputMode(chart)
	local noteSkin = game.noteSkinModel:loadNoteSkin(input_mode)
	noteSkin:loadData()
	self.noteSkin = noteSkin

	local paths = self:getResourcePaths(noteSkin, chartview)
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

	game.multiplayerModel.client:setPlaying(true)
	game.offsetController:updateOffsets()

	game.windowModel:setVsyncOnSelect(false)
	self:play()

	self.loaded = true
	return true
end

---@param autoplay boolean?
function GameplayInteractor:load(autoplay)
	local game = self.game

	game:recreateRhythmEngine()

	local loader = RhythmEngineLoader(
		game.replayBase,
		game.computeContext,
		game.configModel.configs.settings,
		game.resource_loader.resources
	)
	loader:setAudioEnabled(not self.audio_disabled)
	loader:load(game.rhythm_engine)

	self.gameplay_session = GameplaySession(game.rhythm_engine)
	
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

function GameplayInteractor:update()
	if not self.loaded then
		return
	end

	local game = self.game
	self.gameplay_session:update(game.global_timer:getTime())
	game.pauseModel:update()
end

---@param delta number
function GameplayInteractor:increasePlaySpeed(delta)
	local game = self.game

	local speedModel = game.speedModel
	speedModel:increase(delta)

	local gameplay = game.configModel.configs.settings.gameplay
	game.rhythm_engine:setVisualRate(gameplay.speed, gameplay.scaleSpeed)
end

---@return boolean
function GameplayInteractor:hasResult()
	return self.gameplay_session and self.gameplay_session:hasResult() or false
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
	if physic_event then
		local virtual_event = self.input_binder:transform(physic_event)
		if virtual_event then
			self.gameplay_session:receive(virtual_event, game.global_timer:getTime())
		end
	end
end

return GameplayInteractor
