local thread = require("thread")
local erfunc = require("chart.scoring.erfunc")
local class = require("class")
local Observable = require("Observable")

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
---@param localProvider rizu.select.IScoreProvider
---@param onlineProvider rizu.select.IScoreProvider
function ScoreStore:new(configModel, localProvider, onlineProvider)
	self.configModel = configModel
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

---@param i integer
---@return sea.Chartplay?
function ScoreStore:get(i)
	return self.items[i]
end

function ScoreStore:clear()
	self.items = {}
	self:emitChanged({type = "score_items_changed", items = self.items})
end

---@return number
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

	local filters = self.configModel.configs.filters.score
	local select = self.configModel.configs.select
	local index
	for i, filter in ipairs(filters) do
		if filter.name == select.scoreFilterName then
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
		self.items = {}
		self:emitChanged({type = "score_items_changed", items = self.items})
		return
	end

	if score_scope == "chartdiff" and (not chartview.modifiers or not chartview.rate or not chartview.mode) then
		self.items = {}
		self:emitChanged({type = "score_items_changed", items = self.items})
		return
	end

	self.items = {}

	local select = self.configModel.configs.select
	local provider = select.scoreSourceName == "online" and self.onlineProvider or self.localProvider

	---@type sea.Chartplay[]
	local chartplays
	if score_scope == "chartdiff" then
		chartplays = provider:getChartplaysForChartdiff(chartview)
	elseif score_scope == "chartmeta" then
		chartplays = provider:getChartplaysForChartmeta(chartview)
	else
		error("unknown score scope: " .. tostring(score_scope))
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
