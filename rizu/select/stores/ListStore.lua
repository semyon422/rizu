local class = require("class")
local ExpireTable = require("ExpireTable")
local Observable = require("Observable")
local table_util = require("table_util")

---@class rizu.select.stores.ListStore
---@operator call: rizu.select.stores.ListStore
---@field generation integer
---@field itemsCount integer
local ListStore = class()

---@param library rizu.library.Library
---@param timer time.ITimer
function ListStore:new(library, timer)
	self.library = library
	self.observable = Observable()

	---@type cdata?
	self.items = nil
	self.itemsCount = 0
	self.maps = {}
	self.mode = "chartmetas"
	self.generation = 0

	local cache = ExpireTable(timer)
	self.cache = cache
	self.cache.load = function(_, k)
		return self:_loadObject(k)
	end
end

---@param observer rizu.select.ListStoreEventObserver|rizu.select.ListStoreEventReceiver
---@return util.Observer
function ListStore:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function ListStore:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.ListStoreEvent
function ListStore:emitChanged(event)
	self.observable:send(event)
end

---@param result table?
---@param mode string
function ListStore:setResult(result, mode)
	self.mode = mode
	self.generation = self.generation + 1

	if not result then
		self.items = nil
		self.itemsCount = 0
		self.maps = {}
	else
		self.items, self.itemsCount, self.maps = self.library.chartviewsRepo:unpackResult(result)
	end

	self.cache:new()
	self:emitChanged({type = "list_count_changed", count = self.itemsCount})
end

---@private
---@param index integer
---@return rizu.library.LocatedChartview?
function ListStore:_loadObject(index)
	if not self.items or index < 1 or index > self.itemsCount then
		return nil
	end

	local item = self.library.chartviewsRepo:structToTable(self.items[index - 1])

	if self.library.is_sync or not self.library.worker then
		local chartview = self.library.chartviewsRepo:getChartview(item)
		if not chartview then
			return nil
		end
		---@cast chartview rizu.library.LocatedChartview
		chartview.lamp = item.lamp
		self.library:enrichChartview(chartview)
		table_util.copy(chartview, item)
		return item
	end

	coroutine.wrap(function()
		local params = self.library.chartviewsRepo.params
		local generation = self.generation
		local chartview = self.library:getChartviewAsync(params, item)
		if generation ~= self.generation then
			return
		end
		if chartview then
			---@cast chartview rizu.library.LocatedChartview
			chartview.lamp = item.lamp
			self.library:enrichChartview(chartview)
			table_util.copy(chartview, item)
			self:emitChanged({type = "list_item_loaded", index = index, item = item})
		end
	end)()

	return item
end

---@return integer
function ListStore:count()
	return self.itemsCount
end

---@param i integer
---@return rizu.library.LocatedChartview?
function ListStore:get(i)
	if i < 1 or i > self.itemsCount then
		return nil
	end
	return self.cache:get(i)
end

---@param chartview rizu.library.IChartviewBase
---@return integer
function ListStore:indexof(chartview)
	local maps = self.maps
	local mode = self.mode
	local id

	if mode == "chartfile_sets" then
		id = chartview.chartfile_set_id
		if id and id ~= 0 and maps.set_id_to_global_index[id] then
			return maps.set_id_to_global_index[id]
		end
	elseif mode == "chartfiles" then
		id = chartview.chartfile_id
		if id and id ~= 0 and maps.chartfile_id_to_global_index[id] then
			return maps.chartfile_id_to_global_index[id]
		end
	elseif mode == "chartmetas" then
		local chartfile_id = chartview.chartfile_id
		id = chartview.chartmeta_id
		if chartfile_id and chartfile_id ~= 0 and id and id ~= 0 then
			local key = self.library.chartviewsRepo.getCompositeIndexKey(chartfile_id, id)
			local map = maps.chartfile_chartmeta_id_to_global_index
			if map and map[key] then
				return map[key]
			end
		end
		if id and id ~= 0 and maps.chartmeta_id_to_global_index[id] then
			return maps.chartmeta_id_to_global_index[id]
		end
	elseif mode == "chartdiffs" then
		local chartfile_id = chartview.chartfile_id
		id = chartview.chartdiff_id
		if chartfile_id and chartfile_id ~= 0 and id and id ~= 0 then
			local key = self.library.chartviewsRepo.getCompositeIndexKey(chartfile_id, id)
			local map = maps.chartfile_chartdiff_id_to_global_index
			if map and map[key] then
				return map[key]
			end
		end
		if id and id ~= 0 and maps.chartdiff_id_to_global_index[id] then
			return maps.chartdiff_id_to_global_index[id]
		end
	elseif mode == "chartplays" then
		id = chartview.chartplay_id
		if id and id ~= 0 and maps.chartplay_id_to_global_index[id] then
			return maps.chartplay_id_to_global_index[id]
		end
	end

	id = chartview.chartplay_id
	if id and id ~= 0 and maps.chartplay_id_to_global_index[id] then
		return maps.chartplay_id_to_global_index[id]
	end

	id = chartview.chartdiff_id
	if id and id ~= 0 and maps.chartdiff_id_to_global_index[id] then
		return maps.chartdiff_id_to_global_index[id]
	end

	id = chartview.chartmeta_id
	if id and id ~= 0 and maps.chartmeta_id_to_global_index[id] then
		return maps.chartmeta_id_to_global_index[id]
	end

	id = chartview.chartfile_id
	if id and id ~= 0 and maps.chartfile_id_to_global_index[id] then
		return maps.chartfile_id_to_global_index[id]
	end

	id = chartview.chartfile_set_id
	if id and id ~= 0 and maps.set_id_to_global_index[id] then
		return maps.set_id_to_global_index[id]
	end

	return 1
end

return ListStore
