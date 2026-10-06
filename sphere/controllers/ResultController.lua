local class = require("class")
local simplify_notechart = require("chart.transform.simplify_notechart")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local ReplayLoader = require("sea.replays.ReplayLoader")
local ReplayBase = require("sea.replays.ReplayBase")
local RhythmEngineLoader = require("rizu.gameplay.RhythmEngineLoader")
local Settings = require("rizu.config.Settings")

---@class sphere.ResultController
---@operator call: sphere.ResultController
---@field replay_base sea.ReplayBase?
local ResultController = class()

---@param game sphere.GameController
function ResultController:new(game)
	self.game = game
end

function ResultController:clearReplay()
	self.replay_base = nil
	self.replay = nil
end
function ResultController:load()
	self.game.scoreSelector:pullScore()

	local chartplay = self.game.scoreSelector.chartplay
	if not chartplay then
		return
	end

	self.game.scoreSelector:scrollScore(nil, self.game.scoreSelector.state.chartplayIndex)
end

function ResultController:unload()
	local config = self.game.configModel.configs.select
	config.chartplay_id = config.selected_chartplay_id
end

---@param chartplay sea.Chartplay
---@return string?
function ResultController:getReplayDataAsync(chartplay)
	---@type string?
	local content
	if chartplay.user_name then
		local remote = self.game.onlineModel.authManager.sea_client.remote
		content = remote.submission:getReplayFile(chartplay.replay_hash)
	elseif chartplay.replay_hash then
		content = self.game.fs:read("userdata/replays/" .. chartplay.replay_hash)
	end

	return content
end

---@param mode "replay"|"retry"|"result"
---@param chartplay sea.Chartplay
---@return boolean?
function ResultController:replayNoteChartAsync(mode, chartplay)
	local game = self.game

	-- A failed result load must not leave the previously computed score visible.
	-- The fresh engine remains unloaded, so its score sources are nil until a
	-- replay is successfully loaded below.
	if mode == "result" then
		game:recreateRhythmEngine()
	end

	if not chartplay or not game.chartSelector:chartExists() then
		return
	end

	local replay_data = self:getReplayDataAsync(chartplay)
	if not replay_data then
		print("missing replay data")
		return
	end

	local replay, err = ReplayLoader.load(replay_data)
	if not replay then
		print("load replay:", err)
		return
	end

	if mode ~= "retry" then
		self.replay = replay -- TODO: move it somewhere else
	end

	-- A score's replay base is only for this result calculation. The shared
	-- base is the user's current play configuration and must not be replaced.
	local replayBase = ReplayBase()
	replayBase:importReplayBase(replay)
	self.replay_base = replayBase

	if mode == "retry" then
		game.gameplayInteractor.replaying = false
		game.gameplayInteractor:setReplayBase(nil)
		return game.gameplayInteractor:loadGameplayAsync(game.chartSelector.chartview)
	end

	local computeContext = game.computeContext

	computeContext.chartplay = chartplay

	game.gameplayInteractor.replaying = true
	game.gameplayInteractor:setReplayFrames(replay.frames)

	if mode == "replay" then
		game.gameplayInteractor:setReplayBase(replayBase)
		return game.gameplayInteractor:loadGameplayAsync(game.chartSelector.chartview)
	end

	local chartview = game.chartSelector.chartview

	GameplayChart(game.settings, game.fs, chartview):load(replayBase, game.computeContext)

	RhythmEngineLoader(
		replay,
		game.computeContext,
		game.settings,
		game.resource_loader.resources,
		game.resource_loader.file_paths
	):load(game.rhythm_engine)

	game.computeContext:computePlay(game.rhythm_engine, replay.frames)

	if game.settings:getBoolean(Settings.keys.misc.generate_gif_result) then
		local chart = assert(game.computeContext.chart)
		local GifResult = require("chart.transform.GifResult")
		local gif_result = GifResult()
		local bg_path = game.chartSelector:getBackgroundPath()
		if bg_path then
			local bg_data = game.fs:read(bg_path)
			if bg_data then
				gif_result:setBackgroundData(bg_data)
			end
		end
		local data = gif_result:create(
			chartview,
			chartplay,
			simplify_notechart(chart, {"tap", "hold", "laser"}),
			chart.inputMode:getColumns()
		)
		game.fs:write("userdata/result.gif", data)
	end

	game.gameplayInteractor.replaying = false
end

return ResultController
