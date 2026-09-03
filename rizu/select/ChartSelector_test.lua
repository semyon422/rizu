local ChartSelector = require("rizu.select.ChartSelector")
local ScoreSelector = require("rizu.select.ScoreSelector")
local TestLibraryFactory = require("rizu.select.TestLibraryFactory")
local FunctionTimer = require("time.FunctionTimer")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

local tlf = TestLibraryFactory()
local timer = FunctionTimer(function()
	return 0
end)

local function createSettings()
	local settings = Settings.createConfig(FakeFilesystem())
	local keys = Settings.keys
	settings:setChoice(keys.select.primary_mode, "chartfile_sets")
	settings:setChoice(keys.select.secondary_mode, "chartmetas")
	settings:setChoice(keys.select.diff_column, "msd_diff")
	settings:setBoolean(keys.misc.show_non_mania_charts, true)
	settings:setNumber(keys.gameplay.rating_hit_timing_window, 0.05)
	return settings
end

local function createMockConfigModel()
	return {
		configs = {
			settings = {
				select = {
					locations_in_collections = false,
					primary_mode = "chartfile_sets",
					secondary_mode = "chartmetas",
					diff_column = "msd_diff"
				},
				gameplay = {
					ratingHitTimingWindow = 0.05
				},
				miscellaneous = {
					showNonManiaCharts = true
				}
			},
			select = {
				searchMode = "title",
				collection = "",
				location_id = 0,
				sortFunction = "title",
				selected_filters = {},
				filterString = "",
				lampString = "",
				scoreSourceName = "local",
				scoreFilterName = "all"
			},
			filters = {
				notechart = {},
				score = {{name = "all"}}
			}
		}
	}
end

---@param t testing.T
function test.scrolling(t)
	local charts = {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, set_name = "Set 1", hash = "h1"},
		{chartfile_set_id = 2, chartfile_id = 2, chartmeta_id = 2, chartdiff_id = 2, set_name = "Set 2", hash = "h2"},
		{chartfile_set_id = 3, chartfile_id = 3, chartmeta_id = 3, chartdiff_id = 3, set_name = "Set 3", hash = "h3"}
	}
	local configModel = createMockConfigModel()
	local library = tlf:create()
	tlf:populate(library, charts)
	
	local fs = {read = function() end, getInfo = function() end}

	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	chartSelector:load()

	t:eq(chartSelector.state.levels[1].index, 1)
	t:eq(chartSelector.state.levels[1].id, 1)

	chartSelector:scrollLevel(1, 1)
	t:eq(chartSelector.state.levels[1].index, 2)
	t:eq(chartSelector.state.levels[1].id, 2)
	t:eq(chartSelector.chartview.chartfile_id, 2)

	chartSelector:scrollLevel(1, 1)
	t:eq(chartSelector.state.levels[1].index, 3)
	t:eq(chartSelector.state.levels[1].id, 3)
	t:eq(chartSelector.chartview.chartfile_id, 3)

	-- Scroll back
	chartSelector:scrollLevel(1, -1)
	t:eq(chartSelector.state.levels[1].index, 2)
	t:eq(chartSelector.state.levels[1].id, 2)

	library:unload()
end

function test.chart_navigation(t)
	local charts = {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "h_nav_1", index = 1},
		{chartfile_set_id = 1, chartfile_id = 2, chartmeta_id = 2, chartdiff_id = 2, hash = "h_nav_2", index = 1},
		{chartfile_set_id = 1, chartfile_id = 3, chartmeta_id = 3, chartdiff_id = 3, hash = "h_nav_3", index = 1}
	}
	local configModel = createMockConfigModel()
	local library = tlf:create()
	tlf:populate(library, charts)
	
	local fs = {read = function() end, getInfo = function() end}

	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	chartSelector:load()

	t:eq(chartSelector.state.levels[2].index, 1)
	t:eq(chartSelector.state.levels[2].id, 1)

	chartSelector:scrollLevel(2, 1)
	t:eq(chartSelector.state.levels[2].index, 2)
	t:eq(chartSelector.state.levels[2].id, 2)
	t:eq(chartSelector.chartview.chartfile_id, 2)

	chartSelector:scrollLevel(2, 1)
	t:eq(chartSelector.state.levels[2].index, 3)
	t:eq(chartSelector.state.levels[2].id, 3)
	t:eq(chartSelector.chartview.chartfile_id, 3)

	-- Scroll back
	chartSelector:scrollLevel(2, -1)
	t:eq(chartSelector.state.levels[2].index, 2)
	t:eq(chartSelector.state.levels[2].id, 2)

	library:unload()
end

---@param t testing.T
function test.duplicate_chartmeta_restores_by_chartfile(t)
	local charts = {
		{
			chartfile_set_id = 1,
			chartfile_id = 1,
			chartmeta_id = 10,
			chartdiff_id = 20,
			hash = "duplicate_hash",
			index = 1,
			chartfile_name = "duplicate_1.osu",
		},
		{
			chartfile_set_id = 1,
			chartfile_id = 2,
			chartmeta_id = 10,
			chartdiff_id = 20,
			hash = "duplicate_hash",
			index = 1,
			chartfile_name = "duplicate_2.osu",
		},
		{
			chartfile_set_id = 1,
			chartfile_id = 3,
			chartmeta_id = 10,
			chartdiff_id = 20,
			hash = "duplicate_hash",
			index = 1,
			chartfile_name = "duplicate_3.osu",
		},
	}
	local configModel = createMockConfigModel()
	local library = tlf:create()
	tlf:populate(library, charts)

	local fs = {read = function() end, getInfo = function() end}

	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	chartSelector:load()

	t:eq(chartSelector.stores[2]:count(), 3)

	chartSelector:scrollLevel(2, 1)
	t:eq(chartSelector.state.levels[2].index, 2)
	t:eq(chartSelector.chartview.chartfile_id, 2)
	t:eq(chartSelector.chartview.chartmeta_id, 10)

	chartSelector:pullLevel(2)
	t:eq(chartSelector.state.levels[2].index, 2)
	t:eq(chartSelector.chartview.chartfile_id, 2)

	library:unload()
end

function test.chartview_event(t)
	local charts = {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "h1", index = 1},
		{chartfile_set_id = 1, chartfile_id = 2, chartmeta_id = 2, chartdiff_id = 2, hash = "h2", index = 1}
	}
	local configModel = createMockConfigModel()
	local library = tlf:create()
	tlf:populate(library, charts)
	
	local fs = {read = function() end, getInfo = function() end}

	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	
	local chartviewEvents = 0
	chartSelector:onChanged(function(event)
		if event.type == "chartview_changed" then
			chartviewEvents = chartviewEvents + 1
		end
	end)

	chartSelector:load()
	-- load calls refresh, which calls pullLevel, which also triggers selection event -> pullLevel again
	t:eq(chartviewEvents, 2)

	chartSelector:scrollLevel(2, 1)
	-- scrollLevel calls setChartview
	-- it also calls setSelection(2, ...) which triggers receive -> push setSelection(1, ...)
	-- setSelection(1, ...) if it triggers, might trigger pullLevel again.
	-- But in this test, level 1 index remains same, so no extra pullLevel.
	t:eq(chartviewEvents, 3)

	library:unload()
end

---@param t testing.T
function test.playable_chartview_requires_metadata_and_location(t)
	local configModel = createMockConfigModel()
	local library = tlf:create()
	local fs = {read = function() end, getInfo = function() end}
	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)

	t:eq(chartSelector:isPlayableChartview({chartfile_id = 1, chartmeta_id = 0}), false)
	t:eq(chartSelector:isPlayableChartview({
		chartfile_id = 1,
		chartmeta_id = 1,
		hash = "h",
		index = 1,
		inputmode = "4key",
		location_path = "charts/a.osu",
	}), true)

	library:unload()
end

---@param t testing.T
function test.chart_exists_caches_result_until_chartview_changes(t)
	local configModel = createMockConfigModel()
	local library = tlf:create()
	local checked_paths = {}
	local fs = {
		read = function()
			error("chartExists must not read chart contents")
		end,
		getInfo = function(_, path)
			checked_paths[#checked_paths + 1] = path
			return (path == "charts/a.osu" or path == "charts/song.ifs") and {type = "file"} or nil
		end,
	}
	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)

	---@diagnostic disable-next-line: missing-fields
	chartSelector:setChartview({location_path = "charts/a.osu"})
	t:eq(chartSelector:chartExists(), true)
	t:eq(chartSelector:chartExists(), true)
	t:tdeq(checked_paths, {"charts/a.osu"})

	checked_paths = {}
	---@diagnostic disable-next-line: missing-fields
	chartSelector:setChartview({location_path = "charts/song.ifs/29078/29078.1"})
	t:eq(chartSelector:chartExists(), true)
	t:eq(chartSelector:chartExists(), true)
	t:tdeq(checked_paths, {"charts/song.ifs"})

	checked_paths = {}
	---@diagnostic disable-next-line: missing-fields
	chartSelector:setChartview({location_path = "charts/missing.osu"})
	t:eq(chartSelector:chartExists(), false)
	t:eq(chartSelector:chartExists(), false)
	t:tdeq(checked_paths, {"charts/missing.osu"})

	library:unload()
end

---@param t testing.T
function test.provisional_chartview_does_not_load_chart(t)
	local configModel = createMockConfigModel()
	local library = tlf:create()
	local fs = {read = function() end, getInfo = function() end}
	local chartSelector = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	local load_called = false
	chartSelector.chartLoader = {
		loadChart = function()
			load_called = true
		end,
	}
	chartSelector.chartview = {chartfile_id = 1}

	t:eq(chartSelector:loadChart(), nil)
	t:eq(load_called, false)

	library:unload()
end

---@param t testing.T
function test.find_chartmeta_ignores_current_selection_modes(t)
	local charts = {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "h1", index = 1},
		{chartfile_set_id = 2, chartfile_id = 2, chartmeta_id = 2, chartdiff_id = 2, hash = "target", index = 1},
	}
	local configModel = createMockConfigModel()
	local settings = createSettings()
	settings:setChoice(Settings.keys.select.primary_mode, "chartdiffs")
	settings:setChoice(Settings.keys.select.secondary_mode, "chartplays")
	local library = tlf:create()
	tlf:populate(library, charts)

	local fs = {read = function() end, getInfo = function() end}
	local chartSelector = ChartSelector(configModel, settings, library, fs, {getSelectedItem = function() end}, timer)
	chartSelector.config = configModel.configs.select

	local found
	chartSelector:onChanged(function(event)
		if event.type == "chartmeta_found" then
			found = event
		end
	end)

	chartSelector:findChartmeta("target", 1)

	t:tdeq(found, {type = "chartmeta_found", hash = "target", index = 1})
	t:eq(chartSelector.stores[1].mode, "chartmetas")
	t:eq(chartSelector.stores[2].mode, "chartmetas")
	t:eq(chartSelector.chartview.chartmeta_id, 2)
	t:eq(chartSelector.chartview.hash, "target")
	t:eq(chartSelector.config.chartmeta_id, 2)

	library:unload()
end

function test.score_navigation(t)
	local charts = {
		{chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1, chartdiff_id = 1, hash = "h1", index = 1}
	}
	local configModel = createMockConfigModel()
	local library = tlf:create()
	tlf:populate(library, charts)
	
	-- Insert scores
	tlf:createScore(library, {id = 101, hash = "h1", index = 1, accuracy = 0.9, created_at = 1, rating = 300})
	tlf:createScore(library, {id = 102, hash = "h1", index = 1, accuracy = 0.95, created_at = 2, rating = 200})
	tlf:createScore(library, {id = 103, hash = "h1", index = 1, accuracy = 1.0, created_at = 3, rating = 100})

	local fs = {read = function() end, getInfo = function() end}
	local onlineModel = {authManager = {sea_client = {connected = false}}}
	local replayBase = {}

	local chartModel = ChartSelector(configModel, createSettings(), library, fs, {getSelectedItem = function() end}, timer)
	local scoreSelector = ScoreSelector(configModel, createSettings(), library, onlineModel, replayBase, chartModel.state)
	
	-- Wire them up like SelectionCoordinator would
	chartModel.state:onChanged(function(event)
		if event.type == "selection_changed" and event.level == 2 then
			scoreSelector:setChart(chartModel.chartview)
		end
	end)

	chartModel:load()
	scoreSelector:setChart(chartModel.chartview)

	-- Default selection should be the latest score (highest ID), which is 103
	t:eq(chartModel.state.chartplayIndex, 3)
	t:eq(chartModel.state.chartplayId, 103)

	scoreSelector:scrollScore(-1)
	t:eq(chartModel.state.chartplayIndex, 2)
	t:eq(chartModel.state.chartplayId, 102)
	t:eq(scoreSelector.chartplay.id, 102)

	scoreSelector:scrollScore(-1)
	t:eq(chartModel.state.chartplayIndex, 1)
	t:eq(chartModel.state.chartplayId, 101)
	t:eq(scoreSelector.chartplay.id, 101)

	-- Scroll forward
	scoreSelector:scrollScore(1)
	t:eq(chartModel.state.chartplayId, 102)

	library:unload()
end

return test
