local thread = require("thread")
local Settings = require("rizu.config.Settings")
local Events = require("rizu.api.Events")

--[[
The chart library as the song select screen sees it: a list of sets, and the charts of the selected set.
Search, sort, filters and the selected collection decide which sets are in the list.

	local charts = ui.api.charts
	for i = first_visible, last_visible do
		local set = charts:getSet(i)
		if set.loaded then
			drawRow(set.title, set.artist)
		else
			drawPlaceholderRow()
		end
	end
	charts:on("selection_changed", function(chart) ... end)

Indexes start at 1. A row is always returned for an index inside the list. Its text arrives a page at a
time, a moment after it is first asked for; until then `loaded` is false and only the ids are set.
Rows near the ones you ask for are loaded ahead, so in practice only a jump far away shows unloaded rows.
]]

---A row of either list: a set or a chart. Only the fields below are the contract; the game's row has
---more, and they can be renamed at any time. All of them are nil while `loaded` is false.
---@class rizu.api.Chart
---@field loaded boolean? False while the row holds only its ids.
---@field chartfile_id integer
---@field chartfile_set_id integer
---@field chartmeta_id integer? Nil or 0 for an uncached chart: its file is known, but not read yet.
---@field chartdiff_id integer
---@field chartplay_id integer
---@field hash string
---@field chartfile_name string? File name, the only name an uncached chart has.
---@field set_name string? Directory or archive name of the set.
---@field index integer Which chart of the file, for formats that keep several in one.
---@field title string?
---@field artist string?
---@field name string? Difficulty name.
---@field creator string?
---@field level number?
---@field inputmode string "4key", "7key1scratch", ...
---@field format string "osu", "bms", "stepmania", ...
---@field chartmeta_mode string? The gamemode: "mania", "taiko", ...
---@field chartmeta_timings sea.Timings? How the chart's own format judges it, the "auto timings".
---@field duration number Seconds.
---@field notes_count integer
---@field tempo number? BPM
---@field tempo_min number?
---@field tempo_max number?
---@field mode string The gamemode after the mutators, with the rate applied.
---@field chartdiff_inputmode string The input mode after the mutators.
---@field long_notes_ratio number
---@field msd_diff_data table? Etterna's skill ratings by pattern.
---@field msd_diff_rates number[]? Etterna's overall rating at each music speed.
---@field difftable_chartmetas table[]? The difficulty tables the chart is in.
---@field enps_diff number
---@field osu_diff number
---@field msd_diff number
---@field user_diff number
---@field difficulty number? The column chosen in the settings.
---@field accuracy number? Best local accuracy of the chart. Seconds, normalscore: lower is better.
---@field miss_count integer? Misses of that score.
---@field lamp boolean? True for charts with a score.

---@alias rizu.api.Charts.Event
---| "sets_loading" # A new search, sort, filter or collection is being queried. No arguments.
---| "sets_changed" # The list of sets was replaced. No arguments.
---| "sets_loaded" # Rows of the set list got their data. Arguments: first, last.
---| "charts_changed" # The charts of the selected set were replaced. No arguments.
---| "charts_loaded" # Rows of the chart list got their data. Arguments: first, last.
---| "selection_changed" # Another chart is selected, or its data arrived. Arguments: chart or nil.
---| "can_play_changed" # canPlaySelectedChart() has a new answer. No arguments.
---| "library_changed" # Chart files were added or removed on disk; call refresh() to see them. No arguments.
---| "filters_changed" # A filter was set or all were cleared. No arguments.
---| "collections_changed" # The collections were listed again, or another one is selected. No arguments.
---| "source_changed" # getSource() or getOnlineError() has a new answer. The lists follow with their own events. No arguments.

---Filters with three states: "any" shows everything, "yes" only matching charts, "no" only the others.
---@alias rizu.api.Charts.YesNoFilter
---| "played" # The chart has a score.
---| "scratch" # The chart has a scratch lane.
---| "cached" # The chart file has been read: it has a chartmeta.

---@alias rizu.api.Charts.YesNoValue "any"|"yes"|"no"

---Filters that keep charts matching any of the chosen values. No values means no filtering.
---@alias rizu.api.Charts.ValueFilter
---| "format" # Values are chart formats: "osu", "quaver", "stepmania", "bms", ...
---| "original_input_mode" # Values are "4K", "7K", ... or a full input mode such as "7key1scratch".
---| "actual_input_mode" # Same values, compared against the input mode after modifiers.

---Where the listed charts are.
---@alias rizu.api.Charts.Source
---| "local" # On this computer.
---| "online" # In the remote catalog. Their files are downloaded when they are played; everything else is the same.

---A folder of the library that the set list can be narrowed to.
---@class rizu.api.Collection
---@field kind "library"|"location"|"collection" The whole library, one of its locations, or a folder.
---@field name string Folder name. "/" for the whole library.
---@field label string Names from the top down to this folder, joined with "/". Unique in the list.
---@field depth integer 0 for the whole library.
---@field count integer Sets inside, including nested folders.
---@field path string? For the game.
---@field location_id integer? For the game.

---@class rizu.api.Charts : rizu.api.Events
---@operator call: rizu.api.Charts
---@field on fun(self: rizu.api.Charts, event: rizu.api.Charts.Event, f: function): fun()
---@field private selector rizu.select.ChartSelector
---@field private coordinator rizu.select.SelectionCoordinator?
---@field private syncing boolean The remote catalog is being downloaded.
---@field private online_error string?
---@field private loading boolean
---@field private collections rizu.api.Collection[]
---@field private collections_root rizu.library.Collections.TreeNode?
---@field private collection_of {[rizu.library.Collections.TreeNode]: rizu.api.Collection}
local Charts = Events + {}

-- TODO: weak spot. These are the display names from FilterModel's config. Renaming one there silently
-- turns the filter off here. The filter config should give its filters stable ids.
-- group, name of the "yes" filter, name of the "no" filter
local yes_no_filters = {
	played = {"(not) played", "played", "not played"},
	scratch = {"scratch", "has scratch", "has not scratch"},
	cached = {"chartmeta", "has chartmeta", "has not chartmeta"},
}

local value_filters = {
	format = "format",
	original_input_mode = "original input mode",
	actual_input_mode = "actual input mode",
}

---@param selector rizu.select.ChartSelector
---@param coordinator rizu.select.SelectionCoordinator? Without it there is no remote catalog.
function Charts:new(selector, coordinator)
	Events.new(self)
	self.selector = selector
	self.coordinator = coordinator
	self.syncing = false
	self.loading = false
	self.collections = {}
	self.collection_of = {}

	selector:onChanged(function(event)
		if event.type == "primary_items_loading" then
			self.loading = true
			self:emit("sets_loading")
		elseif event.type == "primary_items_updated" then
			self.loading = false
			self:emit("sets_changed")
		elseif event.type == "chartview_changed" then
			self:emit("selection_changed", event.chartview)
		elseif event.type == "chart_availability_changed" then
			self:emit("can_play_changed")
		end
	end)
	for level, name in ipairs({"sets", "charts"}) do
		selector.stores[level]:onChanged(function(event)
			if event.type == "list_items_loaded" then
				self:emit(name .. "_loaded", event.first, event.last)
			elseif level == 2 then
				self:emit("charts_changed")
			end
		end)
	end
	selector.library.onChartsChanged:add(function()
		self:emit("library_changed")
	end)
	selector.filterModel:onChanged(function()
		self:emit("filters_changed")
	end)
	local function collectionsChanged()
		self:emit("collections_changed")
	end
	selector.collectionSelector:onChanged(collectionsChanged)
	selector.collectionSelector.store:onChanged(collectionsChanged)
end

-- Sets

---@return integer
function Charts:getSetCount() return self.selector.stores[1]:count() end

---True when every set is a single chart, as with the difficulty, level, duration and tempo sorts.
---@return boolean
function Charts:isUngrouped() return self.selector:getPrimaryMode() == "chartmetas" end

---@param index integer
---@return rizu.api.Chart? set nil only outside 1..getSetCount()
function Charts:getSet(index) return self.selector.stores[1]:get(index) --[[@as rizu.api.Chart?]] end

---@return integer index 0 when the list is empty
function Charts:getSelectedSetIndex() return self.selector.state:getPrimary().index end

---@param index integer
function Charts:selectSet(index) self.selector:scrollLevel(1, nil, index) end

---Selects the set `offset` rows away, stopping at the ends of the list.
---@param offset integer
function Charts:moveSet(offset) self.selector:scrollLevel(1, offset) end

function Charts:selectRandomSet() self.selector:scrollRandom() end

---Goes back to the set that was selected before the latest selectRandomSet(), repeatedly.
---The history is emptied whenever the set list is queried again.
function Charts:undoRandomSet() self.selector:scrollRandomUndo() end

-- Charts of the selected set

---@return integer
function Charts:getChartCount() return self.selector.stores[2]:count() end

---@param index integer
---@return rizu.api.Chart? chart nil only outside 1..getChartCount()
function Charts:getChart(index) return self.selector.stores[2]:get(index) --[[@as rizu.api.Chart?]] end

---@return integer index 0 when the set has no charts
function Charts:getSelectedChartIndex() return self.selector.state:getSecondary().index end

---@param index integer
function Charts:selectChart(index) self.selector:scrollLevel(2, nil, index) end

---Selects the chart `offset` rows away, stopping at the ends of the list.
---@param offset integer
function Charts:moveChart(offset) self.selector:scrollLevel(2, offset) end

---@return rizu.api.Chart? chart The chart that Play would start.
function Charts:getSelectedChart() return self.selector.chartview --[[@as rizu.api.Chart?]] end

---False while the selected chart's file is missing or still being checked.
---@return boolean
function Charts:canPlaySelectedChart() return self.selector:chartExists() end

-- Query

---True between "sets_loading" and "sets_changed".
---@return boolean
function Charts:isLoading() return self.loading or self.syncing end

---Queries the set list again, keeping the selection where possible.
function Charts:refresh() self.selector:noDebounceRefresh() end

---@return string
function Charts:getSearch() return self.selector.searchModel:getSearchString() end

---The list is queried again shortly after the last call, so this can be called on every keystroke.
---@param text string
function Charts:setSearch(text) self.selector.searchModel:setSearchString(text) end

---@return string
function Charts:getLampSearch() return self.selector.searchModel:getLampString() end

---Same syntax as the search, but applied to the scores that decide which charts get a lamp.
---@param text string
function Charts:setLampSearch(text) self.selector.searchModel:setLampString(text) end

---@return string[] names
function Charts:getSortNames() return self.selector.sortModel.names end

---@return string name
function Charts:getSort() return self.selector.settings:getString(Settings.keys.select.sort_function) end

---@param name string One of getSortNames().
function Charts:setSort(name) self.selector:setSortFunction(name) end

-- Filters. Setting one queries the set list again.

---@param filter rizu.api.Charts.YesNoFilter
---@return rizu.api.Charts.YesNoValue
function Charts:getYesNoFilter(filter)
	local group, yes, no = unpack(yes_no_filters[filter])
	local model = self.selector.filterModel
	return model:isActive(group, yes) and "yes" or model:isActive(group, no) and "no" or "any"
end

---@param filter rizu.api.Charts.YesNoFilter
---@param value rizu.api.Charts.YesNoValue
function Charts:setYesNoFilter(filter, value)
	local group, yes, no = unpack(yes_no_filters[filter])
	local model = self.selector.filterModel
	model:setFilter(group, yes, value == "yes")
	model:setFilter(group, no, value == "no")
	model:commit()
end

---@param filter rizu.api.Charts.ValueFilter
---@return string[] values Sorted.
function Charts:getFilterValues(filter)
	return self.selector.filterModel:getValues(value_filters[filter])
end

---@param filter rizu.api.Charts.ValueFilter
---@param values string[]
function Charts:setFilterValues(filter, values)
	local model = self.selector.filterModel
	model:setValues(value_filters[filter], values)
	model:commit()
end

---How many of the filters above are narrowing the list.
---@return integer
function Charts:getActiveFilterCount()
	local model = self.selector.filterModel
	local count = 0
	for _, names in pairs(yes_no_filters) do
		if model:hasActiveFilters(names[1]) then count = count + 1 end
	end
	for _, group in pairs(value_filters) do
		if model:hasActiveFilters(group) then count = count + 1 end
	end
	return count
end

function Charts:clearFilters() self.selector.filterModel:clearFilters() end

-- Collections

---@param node rizu.library.Collections.TreeNode
---@param label string
---@return rizu.api.Collection
local function newCollection(node, label)
	return {
		kind = node.depth == 0 and "library" or node.path == nil and "location" or "collection",
		name = node.name,
		label = label,
		depth = node.depth,
		count = node.count,
		path = node.path,
		location_id = node.location_id,
	}
end

---@param collections rizu.api.Collection[]
---@param collection_of {[rizu.library.Collections.TreeNode]: rizu.api.Collection}
---@param node rizu.library.Collections.TreeNode
---@param prefix string
local function addCollections(collections, collection_of, node, prefix)
	for _, item in ipairs(node.items) do
		-- The first item of a node points back up the tree.
		if item.depth > node.depth then
			local collection = newCollection(item, prefix .. item.name)
			table.insert(collections, collection)
			collection_of[item] = collection
			addCollections(collections, collection_of, item, collection.label .. "/")
		end
	end
end

---Every collection, parents before their children. The first one is the whole library.
---Empty until the game has listed them; "collections_changed" tells when. The same tables are
---returned until the game lists them again, so they can be compared with ==.
---@return rizu.api.Collection[]
function Charts:getCollections()
	local root = self.selector.collectionSelector.store.root_tree
	if root ~= self.collections_root then
		self.collections_root = root
		self.collections = {}
		self.collection_of = {}
		if root then
			self.collections[1] = newCollection(root, root.name)
			self.collection_of[root] = self.collections[1]
			addCollections(self.collections, self.collection_of, root, "")
		end
	end
	return self.collections
end

---@return rizu.api.Collection? collection One of getCollections().
function Charts:getSelectedCollection()
	local collections = self:getCollections()
	if not collections[1] then return end
	return self.collection_of[self.selector.collectionSelector:getSelectedItem()] or collections[1]
end

---Narrows the set list to a collection and queries it again.
---@param collection rizu.api.Collection? nil for the whole library.
function Charts:selectCollection(collection)
	self.selector.collectionSelector:selectCollection(collection and collection.path, collection and collection.location_id)
end

---True when the collections start with the library's locations, each holding its own folders.
---@return boolean
function Charts:getLocationsInCollections()
	return self.selector.settings:getBoolean(Settings.keys.select.locations_in_collections)
end

---Lists the collections again, grouped by location or not, and keeps the selected one if it is still there.
---@param enabled boolean
function Charts:setLocationsInCollections(enabled)
	self.selector.collectionSelector:setLocationsInCollections(enabled)
end

-- Source

---@return rizu.api.Charts.Source
function Charts:getSource()
	local config = self.selector.config
	return config and config.online and "online" or "local"
end

---Lists the charts of the remote catalog, or the ones on this computer. Going online downloads the
---catalog when it is missing or a day old: `isLoading()` is true meanwhile.
---@param source rizu.api.Charts.Source
function Charts:setSource(source)
	local coordinator = self.coordinator
	if not coordinator or source == self:getSource() then return end
	self.online_error = nil
	self.selector:setOnline(source == "online")
	self:emit("source_changed")
	if source ~= "online" then return end

	self.syncing = true
	self:emit("sets_loading")
	thread.coro(function()
		local ok, err = coordinator:syncOnline()
		self.syncing = false
		self.online_error = not ok and err or nil
		self:emit("source_changed")
	end)()
end

---Why the remote catalog could not be downloaded, if it could not. Charts of an older catalog may be listed anyway.
---@return string? error
function Charts:getOnlineError() return self.online_error end

-- Library

---Tells an empty list from an empty library: f gets true when there are no chart files at all.
---@param f fun(empty: boolean)
function Charts:checkLibraryEmpty(f)
	thread.coro(function()
		f(not self.selector.library:hasChartfilesAsync())
	end)()
end

return Charts
