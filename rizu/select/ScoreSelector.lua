local class = require("class")
local delay = require("delay")
local Observable = require("Observable")
local ScoreStore = require("rizu.select.stores.ScoreStore")
local LocalScoreProvider = require("rizu.select.providers.LocalScoreProvider")
local OnlineScoreProvider = require("rizu.select.providers.OnlineScoreProvider")

---@class rizu.select.ScoreSelector
---@operator call: rizu.select.ScoreSelector
local ScoreSelector = class()

---@param configModel sphere.ConfigModel
---@param library rizu.library.Library
---@param onlineModel sphere.OnlineModel
---@param replayBase sea.ReplayBase
---@param state rizu.select.SelectionState
function ScoreSelector:new(configModel, library, onlineModel, replayBase, state)
	self.configModel = configModel
	self.library = library
	self.onlineModel = onlineModel
	self.replayBase = replayBase
	self.state = state

	local localProvider = LocalScoreProvider(library)
	local onlineProvider = OnlineScoreProvider(onlineModel)
	self.store = ScoreStore(configModel, localProvider, onlineProvider)
	self.store.onChanged:add(self)

	self.onChanged = Observable()
	self.debounceTime = 0.5
end

function ScoreSelector:receive(event)
	if event.items then
		self:findScore()
		return
	end

	if event.type == "selection" and event.level == 2 then
		self:setChart(self.chartview)
	elseif event.type == "find_notechart" or event.type == "set_changed" then
		self:setChart(self.chartview)
	end
end

---@param chartview table?
function ScoreSelector:setChart(chartview)
	self.chartview = chartview
	self.chartplay = nil

	if not chartview then
		self:clear()
		self.state:setScore(1, nil)
		return
	end

	self:pullScore()
end

function ScoreSelector:clear()
	self.chartplay = nil
	self.store:clear()
end

function ScoreSelector:findScore()
	local config = self.configModel.configs.select
	local chartplays = self.store.items
	local index = self.store:getItemIndex(config.chartplay_id) or 1
	local chartplay = chartplays[index]

	if chartplay then
		config.chartplay_id = chartplay.id
	end

	self.state:setScore(index, chartplay and chartplay.id)
	self.chartplay = chartplay
end

---@param noUpdate boolean?
function ScoreSelector:pullScore(noUpdate)
	local chartview = self.chartview
	if not chartview then return end

	if noUpdate then
		self:findScore()
		return
	end

	local select = self.configModel.configs.select
	if select.scoreSourceName == "online" then
		self.store:clear()
		if coroutine.running() then
			delay.sleep(self.debounceTime)
		end
	end

	local config = self.configModel.configs.settings.select
	local secondary_mode = config.secondary_mode or "chartmetas"
	local exact = secondary_mode == "chartdiffs" or secondary_mode == "chartplays"
	
	-- We use the coro version to ensure the task runner waits for completion
	self.store:updateItems(chartview, exact)
end

---@param direction number?
---@param destination number?
function ScoreSelector:scrollScore(direction, destination)
	local items = self.store.items

	destination = math.min(math.max(destination or self.state.chartplayIndex + direction, 1), #items)
	if not items[destination] or self.state.chartplayIndex == destination then
		return
	end

	local chartplay = items[destination]
	local config = self.configModel.configs.select
	config.chartplay_id = chartplay.id

	self.state:setScore(destination, chartplay.id)

	self.chartplay = chartplay
	self.onChanged:send({type = "scroll_score", chartplay = chartplay})
end

---@param chartview table
function ScoreSelector:updateReplayBase(chartview)
	local config = self.configModel.configs.settings.select
	local secondary_mode = config.secondary_mode or "chartmetas"
	if secondary_mode == "chartfile_sets" or secondary_mode == "chartfiles" or secondary_mode == "chartmetas" then
		return
	end

	local replayBase = self.replayBase

	replayBase.modifiers = chartview.modifiers or {}
	replayBase.rate = chartview.rate or 1
	replayBase.mode = chartview.mode or "mania"

	if secondary_mode == "chartdiffs" then
		return
	end

	replayBase.nearest = chartview.nearest or false
	replayBase.tap_only = chartview.tap_only or false
	replayBase.timings = chartview.timings
	replayBase.subtimings = chartview.subtimings
	replayBase.columns_order = chartview.columns_order
	replayBase.custom = chartview.custom or false
	replayBase.const = chartview.const or false
	replayBase.rate_type = chartview.rate_type or "linear"
end

return ScoreSelector
