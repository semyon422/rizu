local class = require("class")
local ChartfileReader = require("rizu.library.ChartfileReader")
local delay = require("delay")
local Observable = require("Observable")
local SelectionState = require("rizu.select.SelectionState")
local ListStore = require("rizu.select.stores.ListStore")
local SearchModel = require("rizu.select.SearchModel")
local SortModel = require("rizu.select.SortModel")
local FilterModel = require("rizu.select.FilterModel")
local SelectionQueryBuilder = require("rizu.select.SelectionQueryBuilder")
local ChartMetadataService = require("rizu.select.services.ChartMetadataService")
local TaskRunner = require("rizu.select.tasks.TaskRunner")

---@class rizu.select.ChartSelector
---@operator call: rizu.select.ChartSelector
local ChartSelector = class()

ChartSelector.debounceTime = 0.5

local LEVELS = {
	chartfile_sets = 1,
	chartfiles = 2,
	chartmetas = 3,
	chartdiffs = 4,
	chartplays = 5,
}

---@param configModel sphere.ConfigModel
---@param library rizu.library.Library
---@param fs fs.IFilesystem
---@param collectionSelector rizu.select.CollectionSelector
---@param timer time.ITimer
---@param state? rizu.select.SelectionState
function ChartSelector:new(configModel, library, fs, collectionSelector, timer, state)
	self.configModel = configModel
	self.library = library
	self.fs = fs
	self.collectionSelector = collectionSelector
	self.state = state or SelectionState()

	---@type rizu.select.stores.ListStore[]
	self.stores = {
		ListStore(library, timer), -- Primary
		ListStore(library, timer), -- Secondary
	}

	self.searchModel = SearchModel(configModel)
	self.filterModel = FilterModel(configModel)
	self.sortModel = SortModel()
	self.queryBuilder = SelectionQueryBuilder(configModel, self.sortModel, self.searchModel, self.filterModel)
	self.metadataService = ChartMetadataService(fs)
	self.taskRunner = TaskRunner()

	self.observable = Observable()
	self.state:onChanged(self)

	self:onChanged(function(event)
		if event.type == "chartview" then
			local chartview = event.chartview
			if chartview then
				print(chartview.chartfile_id, chartview.title)
			end
		end
	end)

	self.stores[1]:onChanged(function(event)
		if event.type == "item_loaded" then
			local current = self.state:getSelection(1)
			if event.index == current.index then
				self:setChanged()
			end
		end
	end)
	self.stores[2]:onChanged(function(event)
		if event.type == "item_loaded" then
			local current = self.state:getSelection(2)
			if event.index == current.index then
				self:emitChanged({type = "chartview", chartview = self.chartview})
				self:setChanged()
			end
		end
	end)
end

---@param observer rizu.select.ChartSelectorEventObserver|rizu.select.ChartSelectorEventReceiver
---@return util.Observer
function ChartSelector:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function ChartSelector:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.ChartSelectorEvent
function ChartSelector:emitChanged(event)
	self.observable:send(event)
end

---@param chartview rizu.library.LocatedChartview?
function ChartSelector:setChartview(chartview)
	self.chartview = chartview
	self.changed = true
	self:emitChanged({type = "chartview", chartview = chartview})
end

---@param event rizu.select.SelectionStateEvent
function ChartSelector:receive(event)
	if event.type == "selection" then
		if event.level == 1 then
			self.taskRunner:push(function()
				self:pullLevel(2)
			end, TaskRunner.priority.high)
		elseif event.level == 2 then
			self.taskRunner:push(function()
				local index = self.stores[1]:indexof(self.config)
				local item = self.stores[1]:get(index)
				self.state:setSelection(1, index, item and item.chartfile_set_id)
			end, TaskRunner.priority.low)
		end
	end
end

function ChartSelector:load()
	local config = self.configModel.configs.select
	self.config = config

	self.searchMode = config.searchMode
	self.filterModel:apply()

	self:noDebounceRefresh()
end

function ChartSelector:updatePrimaryItems()
	local collectionItem = self.collectionSelector:getSelectedItem()
	local params = self.queryBuilder:build(self.config, collectionItem)

	local result = self.library:queryAsync(params)
	self.library.chartviewsRepo.params = params -- ensure repo has current params for getChartview in ListStore
	self.stores[1]:setResult(result, self:getPrimaryMode())
	self:emitChanged({type = "update_primary_items"})
end

---@param hash string
---@param index integer
function ChartSelector:findNotechart(hash, index)
	local config = self.configModel.configs.settings.select
	local params = {
		where = {hash = hash, index = index},
		difficulty = config.diff_column,
	}
	self.taskRunner:push(function()
		local result = self.library:queryAsync(params)
		if result then
			self.library.chartviewsRepo.params = params
			self.stores[1]:setResult(result, "chartmetas")
			local item = self.stores[1]:get(1)
			if item then
				local result2 = self.library:getViewsAsync(params, item)
				self.stores[2]:setResult(result2, "chartmetas")

				local chartview = self.stores[2]:get(1)
				self:setChartview(chartview)
				self:setConfig(chartview)
				self.state:setSelection(1, 1, chartview.chartfile_set_id)
				self.state:setSelection(2, 1, chartview.chartfile_id)
			end
			self:emitChanged({type = "find_notechart", hash = hash, index = index})
		end
	end, TaskRunner.priority.high)
end

---@return string?
function ChartSelector:getBackgroundPath()
	local chartview = self.chartview
	if not chartview or not chartview.title then return end
	return self.metadataService:getBackgroundPath(chartview)
end

---@return string?
---@return number?
---@return string?
function ChartSelector:getAudioPathPreview()
	local chartview = self.chartview
	if not chartview or not chartview.title then return end
	return self.metadataService:getAudioPathPreview(chartview)
end

---@param settings table?
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartSelector:loadChart(settings)
	local chartview = self.chartview
	if not chartview or not chartview.title then return end
	return self.metadataService:loadChart(chartview)
end

---@param settings table?
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartSelector:loadChartAbsolute(settings)
	local chartview = self.chartview
	if not chartview or not chartview.title then return end
	return self.metadataService:loadChartAbsolute(chartview)
end

---@return boolean
function ChartSelector:isChanged()
	local changed = self.changed
	self.changed = false
	return changed == true
end

function ChartSelector:setChanged()
	self.changed = true
	self:emitChanged({type = "set_changed"})
end

---@return boolean
function ChartSelector:notechartExists()
	local chartview = self.chartview
	if chartview and chartview.location_path then
		return ChartfileReader.getInfo(self.fs, chartview.location_path) ~= nil
	end
	return false
end

function ChartSelector:debounceRefresh(...)
	delay.debounce(self, "refreshDebounce", self.debounceTime, self.refresh, self, ...)
end

function ChartSelector:noDebounceRefresh(...)
	local args = {...}
	self.taskRunner:push(function()
		self:refresh(unpack(args))
		if self.chartview then
			self:setConfig(self.chartview)
		end
	end, TaskRunner.priority.high)
end

---@param sortFunctionName string
function ChartSelector:setSortFunction(sortFunctionName)
	self.config.sortFunction = sortFunctionName
	self:noDebounceRefresh()
end

---@param locked boolean
function ChartSelector:setLock(locked)
	self.locked = locked
end

---@return string
function ChartSelector:getPrimaryMode()
	local select_config = self.configModel.configs.settings.select
	return select_config.primary_mode or "chartmetas"
end

---@return string
function ChartSelector:getSecondaryResultMode()
	local select_config = self.configModel.configs.settings.select
	local primary_mode = select_config.primary_mode or "chartmetas"
	local secondary_mode = select_config.secondary_mode or "chartmetas"

	if LEVELS[secondary_mode] >= LEVELS[primary_mode] then
		return secondary_mode
	end
	return primary_mode
end

function ChartSelector:scrollRandom()
	local itemsCount = self.stores[1]:count()
	local destination = math.random(1, itemsCount)
	self:scrollLevel(1, nil, destination)
end

---@param chartview rizu.library.IChartviewBase?
function ChartSelector:setConfig(chartview)
	if not chartview or not chartview.chartfile_id or chartview.chartfile_id == 0 then return end
	self.config.chartfile_set_id = chartview.chartfile_set_id
	self.config.chartfile_id = chartview.chartfile_id
	self.config.chartmeta_id = chartview.chartmeta_id
	self.config.chartdiff_id = chartview.chartdiff_id
	self.config.chartplay_id = chartview.chartplay_id
	self.config.select_chartplay_id = chartview.chartplay_id
end

---@param level integer
---@param direction integer?
---@param destination integer?
function ChartSelector:scrollLevel(level, direction, destination)
	local store = self.stores[level]
	local current = self.state:getSelection(level)
	local itemsCount = store:count()

	destination = math.min(math.max(destination or current.index + direction, 1), itemsCount)
	if current.index == destination then
		return
	end

	local item = store:get(destination)
	if not item then return end

	self:setConfig(item)

	if level == 1 then
		self.state:setSelection(1, destination, item.chartfile_set_id)
	else
		self:setChartview(item)
		self.state:setSelection(2, destination, item.chartfile_id)
		self:emitChanged({type = "scroll_level", level = level, chartview = item})
	end
end

---@param noUpdate boolean?
---@param noPullNext boolean?
function ChartSelector:refresh(noUpdate, noPullNext)
	if self.locked then return end

	if not noUpdate then
		self:updatePrimaryItems()
	end

	local index = self.stores[1]:indexof(self.config)
	local item = self.stores[1]:get(index)

	if item and item.chartfile_set_id and item.chartfile_set_id ~= 0 then
		self:setConfig(item)
	else
		self.config.chartfile_set_id = nil
		self.config.chartfile_id = nil
		self.config.chartmeta_id = nil
		self.config.chartdiff_id = nil
		self.config.chartplay_id = nil

		self:setChartview(nil)

		self.stores[2]:setResult(nil, self:getSecondaryResultMode())
	end

	self.state:setSelection(1, index, item and item.chartfile_set_id)

	if item and not noPullNext then
		self:pullLevel(2)
	end
end

---@param level integer
function ChartSelector:pullLevel(level)
	if level ~= 2 then return end -- Currently only supports 2 levels

	local parentItem = self.stores[1]:get(self.state:getSelection(1).index)
	if parentItem and parentItem.chartfile_set_id and parentItem.chartfile_set_id ~= 0 then
		local params = self.queryBuilder:build(self.config)
		local result = self.library:getViewsAsync(params, parentItem)
		self.stores[2]:setResult(result, self:getSecondaryResultMode())
	else
		self.stores[2]:setResult(nil, self:getSecondaryResultMode())
	end

	local index = self.stores[2]:indexof(self.config)
	local chartview = self.stores[2]:get(index)

	if chartview and chartview.chartfile_id and chartview.chartfile_id ~= 0 then
		self:setConfig(chartview)
	else
		self.config.chartfile_id = nil
		self.config.chartmeta_id = nil
		self.config.chartdiff_id = nil
		self.config.chartplay_id = nil
	end

	self:setChartview(chartview)

	self.state:setSelection(2, index, chartview and chartview.chartfile_id)
end

return ChartSelector
