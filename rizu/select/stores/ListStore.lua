local class = require("class")
local Observable = require("Observable")
local table_util = require("table_util")

---@class rizu.select.stores.ListStore
---@operator call: rizu.select.stores.ListStore
---@field generation integer
---@field itemsCount integer
---@field private pages {[integer]: rizu.select.stores.ListStore.Page}
---@field private pages_count integer
---@field private clock integer
local ListStore = class()

---@class rizu.select.stores.ListStore.Page
---@field items {[integer]: rizu.library.LocatedChartview}
---@field used integer

-- Rows are loaded a page at a time, one worker call each.
ListStore.page_size = 64
-- Rows this close to a requested one are loaded too, so scrolling does not reach unloaded rows.
ListStore.prefetch = 32
ListStore.max_pages = 32

---@param library rizu.library.Library
function ListStore:new(library)
	self.library = library
	self.observable = Observable()

	---@type cdata?
	self.items = nil
	self.itemsCount = 0
	self.maps = {}
	self.mode = "chartmetas"
	self.generation = 0
	self.pages = {}
	self.pages_count = 0
	self.clock = 0
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

---@param result rizu.library.ChartviewsRepo.PackedQueryResult?
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

	self.pages = {}
	self.pages_count = 0
	self:emitChanged({type = "list_count_changed", count = self.itemsCount})
end

---Copies the lamps of a query of some of these rows, made with the same params, into them.
---@param result rizu.library.ChartviewsRepo.PackedQueryResult
function ListStore:updateLamps(result)
	local repo = self.library.chartviewsRepo
	local rows, count = repo:unpackResult(result)
	for j = 0, count - 1 do
		local row = rows[j]
		local i = self:indexof(repo:structToTable(row))
		local item = i <= self.itemsCount and self.items[i - 1]
		-- indexof falls back to coarser ids, and a new score changes MAX(chartplay_id) outside the chartplays mode.
		if item and item.chartfile_id == row.chartfile_id and item.chartmeta_id == row.chartmeta_id
			and item.chartdiff_id == row.chartdiff_id
			and (self.mode ~= "chartplays" or item.chartplay_id == row.chartplay_id)
		then
			item.lamp = row.lamp
			local page = self.pages[math.floor((i - 1) / self.page_size)]
			local loaded = page and page.items[i]
			if loaded then loaded.lamp = row.lamp end
		end
	end
end

---@private
---@param page rizu.select.stores.ListStore.Page
---@param first integer
---@param chartviews (rizu.library.Chartview|false)[]
---@param keep_missing boolean
function ListStore:fillPage(page, first, chartviews, keep_missing)
	for i, chartview in ipairs(chartviews) do
		local item = page.items[first + i - 1]
		if chartview then
			---@cast chartview rizu.library.LocatedChartview
			chartview.lamp = item.lamp
			chartview.loaded = true
			self.library:enrichChartview(chartview)
			table_util.copy(chartview, item)
		elseif not keep_missing then
			page.items[first + i - 1] = nil
		end
	end
end

---@private
function ListStore:evictPage()
	local oldest ---@type integer?
	for index, page in pairs(self.pages) do
		if not oldest or page.used < self.pages[oldest].used then
			oldest = index
		end
	end
	self.pages[oldest] = nil
	self.pages_count = self.pages_count - 1
end

---@private
---@param page_index integer Zero-based.
---@return rizu.select.stores.ListStore.Page
function ListStore:getPage(page_index)
	self.clock = self.clock + 1
	local page = self.pages[page_index]
	if page then
		page.used = self.clock
		return page
	end

	local first = page_index * self.page_size + 1
	local last = math.min(first + self.page_size - 1, self.itemsCount)
	local repo = self.library.chartviewsRepo
	---@type rizu.library.LocatedChartview[]
	local requested = {}
	page = {items = {}, used = self.clock}
	for i = first, last do
		local item = repo:structToTable(self.items[i - 1]) --[[@as rizu.library.LocatedChartview]]
		item.loaded = false
		page.items[i] = item
		requested[#requested + 1] = item
	end
	self.pages[page_index] = page
	self.pages_count = self.pages_count + 1
	if self.pages_count > self.max_pages then
		self:evictPage()
	end

	if self.library.is_sync or not self.library.worker then
		self:fillPage(page, first, repo:getChartviews(requested), false)
		return page
	end

	coroutine.wrap(function()
		local generation = self.generation
		local chartviews = self.library:getChartviewsAsync(repo.params, requested)
		if generation ~= self.generation then
			return
		end
		self:fillPage(page, first, chartviews, true)
		self:emitChanged({type = "list_items_loaded", first = first, last = last})
	end)()

	return page
end

---@return integer
function ListStore:count()
	return self.itemsCount
end

---Always a row inside the list. `loaded` is false until the worker returns its page.
---@param i integer
---@return rizu.library.LocatedChartview?
function ListStore:get(i)
	local count = self.itemsCount
	if i < 1 or i > count then
		return nil
	end
	local size = self.page_size
	local page_index = math.floor((i - 1) / size)
	local page = self:getPage(page_index)
	local before = math.floor((math.max(i - self.prefetch, 1) - 1) / size)
	local after = math.floor((math.min(i + self.prefetch, count) - 1) / size)
	if before ~= page_index then self:getPage(before) end
	if after ~= page_index then self:getPage(after) end
	return page.items[i]
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
