local Charts = require("rizu.api.Charts")
local ChartSelector = require("rizu.select.ChartSelector")
local CollectionSelector = require("rizu.select.CollectionSelector")
local TestLibraryFactory = require("rizu.select.TestLibraryFactory")
local FunctionTimer = require("time.FunctionTimer")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

---Two sets: "A" with one chart in packs/one, "B" with two charts in packs/two.
---@return rizu.api.Charts charts
---@return rizu.select.ChartSelector selector
---@return rizu.library.Library library
local function createCharts(coordinator, seeds)
	local tlf = TestLibraryFactory()
	local library = tlf:create()
	tlf:populate(library, seeds or {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "a", title = "A",
			set_dir = "packs/one", inputmode = "4key"},
		{chartfile_set_id = 2, chartfile_id = 2, chartmeta_id = 2, chartdiff_id = 2, hash = "b", title = "B",
			set_dir = "packs/two", inputmode = "7key"},
		{chartfile_set_id = 2, chartfile_id = 3, chartmeta_id = 3, chartdiff_id = 3, hash = "c", title = "B",
			set_dir = "packs/two", inputmode = "7key"},
	})
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setChoice(Settings.keys.select.primary_mode, "chartfile_sets")
	local config_model = {configs = {select = {
		searchMode = "title", selected_filters = {}, filterString = "", lampString = "",
	}, filters = require("sphere.persistence.ConfigModel.filters")}}
	local collection_selector = CollectionSelector(config_model, settings, library)
	local selector = ChartSelector(config_model, settings, library, {}, collection_selector,
		FunctionTimer(function() return 0 end))
	return Charts(selector, coordinator), selector, library
end

---@param t testing.T
function test.lists_and_selection(t)
	local charts, selector, library = createCharts()

	local events = {}
	for _, name in ipairs({"sets_loading", "sets_changed", "charts_changed"}) do
		charts:on(name, function() table.insert(events, name) end)
	end
	local selected ---@type rizu.api.Chart?
	local unsubscribe = charts:on("selection_changed", function(chart) selected = chart end)

	selector.collectionSelector:load()
	selector:load()
	t:eq(events[1], "sets_loading")
	t:eq(events[2], "sets_changed")
	t:eq(events[#events], "charts_changed")
	t:eq(charts:isLoading(), false)
	t:eq(charts:getSetCount(), 2)
	t:eq(charts:getSet(1).loaded, true)
	t:eq(charts:getSet(1).title, "A")
	t:eq(charts:getSet(3), nil)
	t:eq(charts:getSelectedSetIndex(), 1)
	t:eq(charts:getChartCount(), 1)

	charts:moveSet(1)
	t:eq(charts:getSelectedSetIndex(), 2)
	t:eq(charts:getChartCount(), 2)
	t:eq(selected, charts:getSelectedChart())
	t:eq(selected.chartfile_id, 2)

	charts:selectChart(2)
	t:eq(charts:getSelectedChartIndex(), 2)
	t:eq(selected.chartfile_id, 3)

	selected = nil
	charts:announceSelection()
	t:eq(selected, charts:getSelectedChart())

	unsubscribe()
	charts:selectSet(1)
	t:eq(selected.chartfile_id, 3)
	t:eq(charts:getSelectedChart().chartfile_id, 1)

	library:unload()
end

---@param t testing.T
function test.random_set_history(t)
	local charts, selector, library = createCharts()
	selector.collectionSelector:load()
	selector:load()

	local picks = {2, 1, 2}
	local random = math.random
	math.random = function() return table.remove(picks, 1) end

	charts:selectRandomSet()
	charts:selectRandomSet()
	charts:selectRandomSet()
	math.random = random
	t:eq(charts:getSelectedSetIndex(), 2)

	charts:undoRandomSet()
	t:eq(charts:getSelectedSetIndex(), 1)
	charts:undoRandomSet()
	t:eq(charts:getSelectedSetIndex(), 2)
	charts:undoRandomSet()
	t:eq(charts:getSelectedSetIndex(), 1)
	charts:undoRandomSet()
	t:eq(charts:getSelectedSetIndex(), 1)

	math.random = function() return 2 end
	charts:selectRandomSet()
	math.random = random
	charts:setSearch("A")
	charts:refresh()
	charts:selectSet(1)
	charts:undoRandomSet()
	t:eq(charts:getSelectedSetIndex(), 1)

	library:unload()
end

---@param t testing.T
function test.filters(t)
	local charts, selector, library = createCharts()
	local changes = 0
	charts:on("filters_changed", function() changes = changes + 1 end)
	selector.collectionSelector:load()
	selector:load()

	t:eq(charts:getActiveFilterCount(), 0)
	t:eq(charts:getYesNoFilter("played"), "any")
	t:tdeq(charts:getFilterValues("original_input_mode"), {})

	charts:setFilterValues("original_input_mode", {"7K"})
	t:tdeq(charts:getFilterValues("original_input_mode"), {"7K"})
	t:eq(charts:getActiveFilterCount(), 1)
	t:eq(changes, 1)
	t:eq(charts:getSetCount(), 1)
	t:eq(charts:getSet(1).title, "B")

	charts:setYesNoFilter("played", "no")
	t:eq(charts:getYesNoFilter("played"), "no")
	t:eq(charts:getActiveFilterCount(), 2)
	charts:setYesNoFilter("played", "any")
	t:eq(charts:getActiveFilterCount(), 1)

	charts:clearFilters()
	t:eq(charts:getActiveFilterCount(), 0)
	t:eq(charts:getSetCount(), 2)

	library:unload()
end

---@param t testing.T
function test.cached_filter(t)
	local charts, selector, library = createCharts(nil, {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "a", title = "A",
			set_dir = "packs/one", inputmode = "4key"},
		{chartfile_set_id = 2, chartfile_id = 2, set_dir = "packs/two", set_name = "two", chartfile_name = "b.osu"},
	})
	selector.collectionSelector:load()
	selector:load()
	t:eq(charts:getSetCount(), 2)

	charts:setYesNoFilter("cached", "yes")
	t:eq(charts:getYesNoFilter("cached"), "yes")
	t:eq(charts:getActiveFilterCount(), 1)
	t:eq(charts:getSetCount(), 1)
	t:eq(charts:getSet(1).title, "A")

	charts:setYesNoFilter("cached", "no")
	t:eq(charts:getSetCount(), 1)
	t:eq(charts:getSet(1).set_name, "two")

	library:unload()
end

---@param t testing.T
function test.collections(t)
	local charts, selector, library = createCharts()
	t:tdeq(charts:getCollections(), {})
	t:eq(charts:getSelectedCollection(), nil)

	local changes = 0
	charts:on("collections_changed", function() changes = changes + 1 end)
	selector.collectionSelector:load()
	t:assert(changes > 0)

	local collections = charts:getCollections()
	local labels = {}
	for i, collection in ipairs(collections) do
		labels[i] = collection.kind .. " " .. collection.label .. " " .. collection.count
	end
	t:tdeq(labels, {"library / 2", "collection packs 2", "collection packs/one 1", "collection packs/two 1"})
	t:eq(charts:getCollections(), collections)
	t:eq(charts:getSelectedCollection(), collections[1])

	charts:selectCollection(collections[4])
	t:eq(charts:getSelectedCollection(), collections[4])
	charts:selectCollection(nil)
	t:eq(charts:getSelectedCollection(), collections[1])

	t:eq(charts:getLocationsInCollections(), false)
	changes = 0
	charts:setLocationsInCollections(true)
	t:eq(charts:getLocationsInCollections(), true)
	t:assert(changes > 0)
	t:eq(charts:getCollections()[2].kind, "location")

	library:unload()
end

---@param t testing.T
function test.online_source_lists_the_remote_locations_only(t)
	local synced = 0
	local sync_error ---@type string?
	local charts, selector, library ---@type rizu.api.Charts, rizu.select.ChartSelector, rizu.library.Library
	charts, selector, library = createCharts({syncOnline = function()
		synced = synced + 1
		selector:noDebounceRefresh()
		return sync_error == nil, sync_error
	end})
	-- The same chart as "a", listed by the catalog.
	local location = library.locationsRepo:insertLocation({
		path = "online", name = "online", is_relative = true, is_internal = false, url = "https://cdn.test",
	})
	local set = library.database.models.chartfile_sets:create({
		location_id = location.id, name = "Online A", dir = "osu_ranked", modified_at = 0, is_file = false,
	})
	library.database.models.chartfiles:create({set_id = set.id, name = "a.osu", hash = "a", modified_at = 0})
	library.locations:selectLocations()

	selector.collectionSelector:load()
	selector:load()
	t:eq(charts:getSource(), "local")
	t:eq(charts:getSetCount(), 2)

	local events = {}
	charts:on("source_changed", function() table.insert(events, charts:getSource()) end)
	charts:setSource("online")
	t:eq(synced, 1)
	t:tdeq(events, {"online", "online"})
	t:eq(charts:isLoading(), false)
	t:eq(charts:getSetCount(), 1)
	local chart = charts:getSelectedChart()
	t:eq(chart.hash, "a")
	t:eq(chart.location_url, "https://cdn.test")
	t:eq(charts:canPlaySelectedChart(), true)
	t:eq(charts:getOnlineError(), nil)

	charts:setSource("local")
	t:eq(charts:getSetCount(), 2)
	t:eq(synced, 1)

	-- A catalog that cannot be downloaded leaves what is known listed, with the reason.
	sync_error = "HTTP 503"
	charts:setSource("online")
	t:eq(charts:getOnlineError(), "HTTP 503")
	t:eq(charts:getSetCount(), 1)

	library:unload()
end

return test
