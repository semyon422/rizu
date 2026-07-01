local class = require("class")
local delay = require("delay")
local Observable = require("Observable")
local ScoreStore = require("rizu.select.stores.ScoreStore")
local LocalScoreProvider = require("rizu.select.providers.LocalScoreProvider")
local OnlineScoreProvider = require("rizu.select.providers.OnlineScoreProvider")
local SelectionReplayBaseApplier = require("rizu.select.services.SelectionReplayBaseApplier")

---@class rizu.select.ScoreSelector
---@operator call: rizu.select.ScoreSelector
---@field onlineScoreCooldownActive boolean
---@field pendingOnlineScoreChartview rizu.library.LocatedChartview?
---@field pendingOnlineScoreGeneration integer?
---@field replayBaseApplier rizu.select.services.SelectionReplayBaseApplier
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
	self.store:onChanged(self)
	self.replayBaseApplier = SelectionReplayBaseApplier(configModel, replayBase)

	self.observable = Observable()
	self.debounceTime = 0.5
	self.generation = 0
	self.onlineScoreCooldownActive = false
	self.pendingOnlineScoreChartview = nil
	self.pendingOnlineScoreGeneration = nil
end

---@param observer rizu.select.ScoreSelectorEventObserver|rizu.select.ScoreSelectorEventReceiver
---@return util.Observer
function ScoreSelector:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function ScoreSelector:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.ScoreSelectorEvent
function ScoreSelector:emitChanged(event)
	self.observable:send(event)
end

---@param event rizu.select.Event
function ScoreSelector:receive(event)
	if event.type == "score_items_changed" then
		self:findScore()
		self:emitChanged(event)
		return
	end

	if event.type == "selection_changed" and event.level == 2 then
		self:setChart(self.chartview)
	elseif event.type == "chartmeta_found" or event.type == "selected_set_changed" then
		self:setChart(self.chartview)
	end
end

---@param chartview rizu.library.LocatedChartview?
function ScoreSelector:setChart(chartview)
	self.chartview = chartview
	self.chartplay = nil

	if not chartview then
		self.generation = self.generation + 1
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

	self.generation = self.generation + 1
	local generation = self.generation

	local select = self.configModel.configs.select
	if select.scoreSourceName == "online" then
		self.store:clear()
		if not chartview.hash or not chartview.index then
			return
		end
		self:updateOnlineScoreItems(chartview, generation)
		return
	end

	self:updateScoreItems(chartview, generation)
end

---@param chartview rizu.library.LocatedChartview
---@param generation integer
function ScoreSelector:updateOnlineScoreItems(chartview, generation)
	if self.onlineScoreCooldownActive then
		self.pendingOnlineScoreChartview = chartview
		self.pendingOnlineScoreGeneration = generation
		return
	end

	self:updateScoreItems(chartview, generation)
	self:startOnlineScoreCooldown()
end

function ScoreSelector:startOnlineScoreCooldown()
	if self.onlineScoreCooldownActive then
		return
	end

	self.onlineScoreCooldownActive = true
	coroutine.wrap(function()
		while true do
			delay.sleep(self.debounceTime)

			local chartview = self.pendingOnlineScoreChartview
			local generation = self.pendingOnlineScoreGeneration
			self.pendingOnlineScoreChartview = nil
			self.pendingOnlineScoreGeneration = nil

			if not chartview or generation ~= self.generation then
				self.onlineScoreCooldownActive = false
				return
			end

			self:updateScoreItems(chartview, generation)
		end
	end)()
end

---@param chartview rizu.library.LocatedChartview
---@return rizu.select.ScoreScope?
function ScoreSelector:getScoreScope(chartview)
	if not chartview.hash or not chartview.index then
		return nil
	end

	local config = self.configModel.configs.settings.select
	local secondary_mode = config.secondary_mode or "chartmetas"
	if secondary_mode == "chartdiffs" or secondary_mode == "chartplays" then
		if chartview.chartdiff_id and chartview.chartdiff_id ~= 0 then
			return "chartdiff"
		end
		return nil
	end

	return "chartmeta"
end

---@param chartview rizu.library.LocatedChartview
---@param generation integer
function ScoreSelector:updateScoreItems(chartview, generation)
	-- We use the coro version to ensure the task runner waits for completion
	self.store:updateItems(chartview, self:getScoreScope(chartview), generation)
end

---@param direction integer?
---@param destination integer?
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
	self:emitChanged({type = "score_scrolled", chartplay = chartplay})
end

---@param chartview rizu.library.LocatedChartview
function ScoreSelector:updateReplayBase(chartview)
	self.replayBaseApplier:apply(chartview)
end

return ScoreSelector
