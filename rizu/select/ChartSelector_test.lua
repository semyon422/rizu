local ChartSelector = require("rizu.select.ChartSelector")
local ScoreSelector = require("rizu.select.ScoreSelector")
local TestLibraryFactory = require("rizu.select.TestLibraryFactory")
local FunctionTimer = require("time.FunctionTimer")

local test = {}

local tlf = TestLibraryFactory()
local timer = FunctionTimer(function()
	return 0
end)

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

	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
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

	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
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

	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
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

	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
	
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
	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)

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
function test.provisional_chartview_does_not_load_chart(t)
	local configModel = createMockConfigModel()
	local library = tlf:create()
	local fs = {read = function() end, getInfo = function() end}
	local chartSelector = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
	local load_called = false
	chartSelector.metadataService = {
		loadChart = function()
			load_called = true
		end,
	}
	chartSelector.chartview = {chartfile_id = 1}

	t:eq(chartSelector:loadChart(), nil)
	t:eq(load_called, false)

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

	local chartModel = ChartSelector(configModel, library, fs, {getSelectedItem = function() end}, timer)
	local scoreSelector = ScoreSelector(configModel, library, onlineModel, replayBase, chartModel.state)
	
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
	t:eq(chartModel.state.scoreId, 103)

	scoreSelector:scrollScore(-1)
	t:eq(chartModel.state.chartplayIndex, 2)
	t:eq(chartModel.state.scoreId, 102)
	t:eq(scoreSelector.chartplay.id, 102)

	scoreSelector:scrollScore(-1)
	t:eq(chartModel.state.chartplayIndex, 1)
	t:eq(chartModel.state.scoreId, 101)
	t:eq(scoreSelector.chartplay.id, 101)

	-- Scroll forward
	scoreSelector:scrollScore(1)
	t:eq(chartModel.state.scoreId, 102)

	library:unload()
end

return test
