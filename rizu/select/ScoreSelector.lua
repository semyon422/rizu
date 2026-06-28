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
	self.store:onChanged(self)

	self.observable = Observable()
	self.debounceTime = 0.5
	self.scoreRequestId = 0
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
	if event.type == "items" then
		self:findScore()
		self:emitChanged(event)
		return
	end

	if event.type == "selection" and event.level == 2 then
		self:setChart(self.chartview)
	elseif event.type == "find_notechart" or event.type == "set_changed" then
		self:setChart(self.chartview)
	end
end

---@param chartview rizu.library.LocatedChartview?
function ScoreSelector:setChart(chartview)
	self.chartview = chartview
	self.chartplay = nil

	if not chartview then
		self.scoreRequestId = self.scoreRequestId + 1
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

	self.scoreRequestId = self.scoreRequestId + 1
	local request_id = self.scoreRequestId

	local select = self.configModel.configs.select
	if select.scoreSourceName == "online" then
		self.store:clear()
		if coroutine.running() then
			coroutine.wrap(function()
				delay.sleep(self.debounceTime)
				if request_id ~= self.scoreRequestId then
					return
				end
				self:updateScoreItems(chartview, request_id)
			end)()
			return
		end
	end

	self:updateScoreItems(chartview, request_id)
end

---@param chartview rizu.library.LocatedChartview
---@param request_id integer
function ScoreSelector:updateScoreItems(chartview, request_id)
	local config = self.configModel.configs.settings.select
	local secondary_mode = config.secondary_mode or "chartmetas"
	local exact = secondary_mode == "chartdiffs" or secondary_mode == "chartplays"
	
	-- We use the coro version to ensure the task runner waits for completion
	self.store:updateItems(chartview, exact, request_id)
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
	self:emitChanged({type = "scroll_score", chartplay = chartplay})
end

---@param chartview rizu.library.LocatedChartview
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
	replayBase.healths = chartview.healths
	replayBase.columns_order = chartview.columns_order
	replayBase.custom = chartview.custom or false
	replayBase.const = chartview.const or false
	replayBase.rate_type = chartview.rate_type or "linear"
end

return ScoreSelector
