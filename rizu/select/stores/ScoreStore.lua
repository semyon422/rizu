local thread = require("thread")
local erfunc = require("chart.scoring.erfunc")
local class = require("class")
local Observable = require("Observable")
local Settings = require("rizu.config.Settings")
local ReplayBaseConfigurator = require("rizu.gameplay.ReplayBaseConfigurator")
local Timings = require("sea.chart.Timings")

---@class rizu.select.stores.ScoreStore
---@operator call: rizu.select.stores.ScoreStore
local ScoreStore = class()

---@alias rizu.select.ScoreScope
---| "chartmeta"
---| "chartdiff"

ScoreStore.scoreSources = {
	"local",
	"online",
}

---@param configModel sphere.ConfigModel
---@param settings rizu.config.Config
---@param localProvider rizu.select.IScoreProvider
---@param onlineProvider rizu.select.IScoreProvider
function ScoreStore:new(configModel, settings, localProvider, onlineProvider)
	self.configModel = configModel
	self.settings = settings
	self.localProvider = localProvider
	self.onlineProvider = onlineProvider
	self.items = {}
	self.observable = Observable()
	self.requestId = 0
end

---@param observer rizu.select.ScoreStoreEventObserver|rizu.select.ScoreStoreEventReceiver
---@return util.Observer
function ScoreStore:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function ScoreStore:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.ScoreStoreEvent
function ScoreStore:emitChanged(event)
	self.observable:send(event)
end

---The system the leaderboard of a chart shows accuracies in, the one that counts the accuracy of its plays,
---see rizu.gameplay.ReplayBaseConfigurator.getAccuracyScoring(). Local scores of mania charts only, the server has no hits.
---@param settings rizu.config.Config
---@param chartview rizu.library.LocatedChartview?
---@return rizu.engine.scoring.Scoring? scoring nil for normalscore, which chartplays.accuracy holds.
function ScoreStore.getScoring(settings, chartview)
	local s = Settings.keys.select
	if not chartview or chartview.chartmeta_mode ~= "mania"
		or not settings:getBoolean(s.rescore)
		or settings:getChoice(s.score_source) ~= "local"
	then
		return
	end
	-- Chartviews come from the library thread as plain tables, without the Timings metatable.
	local timings = chartview.chartmeta_timings
	timings = timings and Timings(timings.name, timings.data)
	return ReplayBaseConfigurator.getAccuracyScoring(settings, timings, chartview.format)
end

---@param i integer
---@return sea.Chartplay?
function ScoreStore:get(i)
	return self.items[i]
end

function ScoreStore:clear()
	self.items = {}
	self:emitChanged({type = "score_items_changed", items = self.items})
end

---@param request_id integer
function ScoreStore:beginLoading(request_id)
	self.requestId = request_id
	self.items = {}
	-- Loading is an explicit state transition, including when the previous
	-- chart had no scores. The UI keeps its rendered rows and shows a spinner.
	self:emitChanged({type = "score_items_changed", items = self.items, loading = true})
end

---@return integer
function ScoreStore:count()
	return #self.items
end

---@param scores sea.Chartplay[]?
---@return sea.Chartplay[]
function ScoreStore:filterScores(scores)
	if not scores then return {} end

	for _, score in ipairs(scores) do
		local s = erfunc.erf(0.032 / (score.accuracy * math.sqrt(2)))
		score.score = s * 10000
	end

	---@type sphere.ScoreFilter[]
	local filters = self.configModel.configs.filters.score
	local score_filter = self.settings:getChoice(Settings.keys.select.score_filter)
	local index
	for i, filter in ipairs(filters) do
		if filter.name == score_filter then
			index = i
			break
		end
	end
	index = index or 1
	local filter = filters[index]
	if not filter.check then
		return scores
	end
	local newScores = {}
	for i, score in ipairs(scores) do
		if filter.check(score) then
			table.insert(newScores, score)
		end
	end
	return newScores
end

---@param chartview sea.ChartmetaKey|sea.ChartdiffKey
---@param score_scope rizu.select.ScoreScope?
---@param request_id integer
---@return nil?
function ScoreStore:updateItemsAsync(chartview, score_scope, request_id)
	self.requestId = request_id

	if not score_scope or not chartview.hash or not chartview.index then
		self:clear()
		return
	end

	if score_scope == "chartdiff" and (not chartview.modifiers or not chartview.rate or not chartview.mode) then
		self:clear()
		return
	end

	local score_source = self.settings:getChoice(Settings.keys.select.score_source)
	local provider = score_source == "online" and self.onlineProvider or self.localProvider

	---@type sea.Chartplay[]
	local chartplays
	if score_scope == "chartdiff" then
		chartplays = provider:getChartplaysForChartdiff(chartview)
	elseif score_scope == "chartmeta" then
		chartplays = provider:getChartplaysForChartmeta(chartview)
	else
		error("unknown score scope: " .. tostring(score_scope))
	end

	-- See rizu.api.Scores:getAccuracy().
	local scoring = ScoreStore.getScoring(self.settings, chartview --[[@as rizu.library.LocatedChartview]])
	if scoring and not scoring:isNormalscore() and chartplays[1] then
		---@type integer[]
		local ids = {}
		for i, chartplay in ipairs(chartplays) do
			ids[i] = chartplay.id
		end
		local provider = self.localProvider --[[@as rizu.select.providers.LocalScoreProvider]]
		local accuracies = provider:getAccuracies(ids, scoring:encode())
		for _, chartplay in ipairs(chartplays) do
			chartplay.rescored_accuracy = accuracies[chartplay.id]
		end
	end

	if request_id ~= self.requestId then
		return
	end

	self.items = self:filterScores(chartplays)
	self:emitChanged({type = "score_items_changed", items = self.items})
end

ScoreStore.updateItems = thread.coro(ScoreStore.updateItemsAsync)

---@param chartplay_id integer
---@return integer
function ScoreStore:getItemIndex(chartplay_id)
	local items = self.items

	if not items then
		return 1
	end

	for i = 1, #items do
		local item = items[i]
		if item.id == chartplay_id then
			return i
		end
	end

	return 1
end

return ScoreStore
