local delay = require("delay")
local ReplayBase = require("sea.replays.ReplayBase")
local ScoreSelector = require("rizu.select.ScoreSelector")
local SelectionState = require("rizu.select.SelectionState")
local ScoreStore = require("rizu.select.stores.ScoreStore")

local test = {}

local function createConfigModel(secondary_mode)
	return {
		configs = {
			settings = {
				select = {
					secondary_mode = secondary_mode,
				},
			},
			select = {
				scoreSourceName = "local",
				scoreFilterName = "all",
			},
			filters = {
				score = {{name = "all"}},
			},
		},
	}
end

local function createSelector(secondary_mode, replayBase)
	local onlineModel = {
		authManager = {
			sea_client = {
				connected = false,
			},
		},
	}
	return ScoreSelector(createConfigModel(secondary_mode), {}, onlineModel, replayBase, SelectionState())
end

---@param t testing.T
function test.update_replay_base_delegates_to_applier(t)
	local replayBase = ReplayBase()
	local selector = createSelector("chartdiffs", replayBase)
	local chartview = {hash = "h", index = 1}
	local applied
	selector.replayBaseApplier = {
		apply = function(_, item)
			applied = item
		end,
	}

	selector:updateReplayBase(chartview)

	t:eq(applied, chartview)
end

---@param t testing.T
function test.build_selection_replay_base_delegates_to_applier(t)
	local replayBase = ReplayBase()
	local selector = createSelector("chartdiffs", replayBase)
	local chartview = {hash = "h", index = 1}
	local candidate = ReplayBase()
	local applied = true
	selector.replayBaseApplier = {
		buildSelectionReplayBase = function(_, item)
			t:eq(item, chartview)
			return candidate, applied
		end,
	}

	local replayBaseCandidate, was_applied = selector:buildSelectionReplayBase(chartview)

	t:eq(replayBaseCandidate, candidate)
	t:eq(was_applied, true)
end

---@param t testing.T
function test.coarse_modes_load_chartmeta_scores(t)
	for _, mode in ipairs({"chartfile_sets", "chartfiles", "chartmetas"}) do
		local replayBase = ReplayBase()
		local selector = createSelector(mode, replayBase)
		local scope
		selector.store = {
			updateItems = function(_, _, score_scope)
				scope = score_scope
			end,
		}

		selector:setChart({hash = "h", index = 1, chartdiff_id = 0})

		t:eq(scope, "chartmeta", mode)
	end
end

---@param t testing.T
function test.chartdiff_and_chartplay_modes_load_exact_chartdiff_scores(t)
	for _, mode in ipairs({"chartdiffs", "chartplays"}) do
		local replayBase = ReplayBase()
		local selector = createSelector(mode, replayBase)
		local scope
		selector.store = {
			updateItems = function(_, _, score_scope)
				scope = score_scope
			end,
		}

		selector:setChart({
			hash = "h",
			index = 1,
			chartdiff_id = 7,
			modifiers = {},
			rate = 1,
			mode = "mania",
		})

		t:eq(scope, "chartdiff", mode)
	end
end

---@param t testing.T
function test.chartdiff_score_visibility_requires_actual_chartdiff(t)
	local replayBase = ReplayBase()
	local selector = createSelector("chartdiffs", replayBase)
	local scope = false
	selector.store = {
		updateItems = function(_, _, score_scope)
			scope = score_scope
		end,
	}

	selector:setChart({hash = "h", index = 1, chartdiff_id = 0})

	t:eq(scope, nil)
end

---@param t testing.T
function test.score_store_clears_incomplete_chartdiff_key(t)
	local configModel = createConfigModel("chartdiffs")
	local provider_called = false
	local provider = {
		getChartplaysForChartmeta = function()
			provider_called = true
			return {}
		end,
		getChartplaysForChartdiff = function()
			provider_called = true
			return {}
		end,
	}
	local store = ScoreStore(configModel, provider, provider)
	store.items = {{id = 1, accuracy = 1}}

	store:updateItemsAsync({hash = "h", index = 1, chartdiff_id = 7}, "chartdiff", 1)

	t:eq(provider_called, false)
	t:eq(store:count(), 0)
end

---@param t testing.T
function test.online_throttle_updates_immediately_and_keeps_latest_pending_chart(t)
	local time = {0}
	delay.set_timer(time)

	local replayBase = ReplayBase()
	local selector = createSelector("chartmetas", replayBase)
	selector.configModel.configs.select.scoreSourceName = "online"

	---@type string[]
	local updated_hashes = {}
	selector.store = {
		clear = function() end,
		updateItems = function(_, chartview)
			table.insert(updated_hashes, chartview.hash)
		end,
	}

	coroutine.wrap(function()
		selector:setChart({hash = "old", index = 1})
	end)()

	t:tdeq(updated_hashes, {"old"})

	selector:setChart({hash = "middle", index = 1})
	selector:setChart({hash = "new", index = 1})
	t:tdeq(updated_hashes, {"old"})

	time[1] = 1
	delay.update()
	t:tdeq(updated_hashes, {"old", "new"})

	time[1] = 2
	delay.update()
	t:tdeq(updated_hashes, {"old", "new"})

	delay.set_timer(function()
		return 0
	end)
end

---@param t testing.T
function test.online_missing_chart_key_does_not_start_throttle(t)
	local time = {0}
	delay.set_timer(time)

	local replayBase = ReplayBase()
	local selector = createSelector("chartmetas", replayBase)
	selector.configModel.configs.select.scoreSourceName = "online"

	---@type string[]
	local updated_hashes = {}
	selector.store = {
		clear = function() end,
		updateItems = function(_, chartview)
			table.insert(updated_hashes, chartview.hash)
		end,
	}

	selector:setChart({chartfile_id = 1})
	t:tdeq(updated_hashes, {})

	selector:setChart({hash = "loaded", index = 1})
	t:tdeq(updated_hashes, {"loaded"})

	time[1] = 1
	delay.update()
	t:tdeq(updated_hashes, {"loaded"})

	delay.set_timer(function()
		return 0
	end)
end

---@param t testing.T
function test.online_debounce_receive_does_not_block_event_dispatch(t)
	local time = {0}
	delay.set_timer(time)

	local replayBase = ReplayBase()
	local selector = createSelector("chartmetas", replayBase)
	selector.configModel.configs.select.scoreSourceName = "online"
	selector.chartview = {hash = "selected", index = 1}

	---@type string[]
	local updated_hashes = {}
	selector.store = {
		clear = function() end,
		updateItems = function(_, chartview)
			table.insert(updated_hashes, chartview.hash)
		end,
	}

	local returned = false
	coroutine.wrap(function()
		selector:receive({type = "selected_set_changed"})
		returned = true
	end)()

	t:eq(returned, true)
	t:tdeq(updated_hashes, {"selected"})

	time[1] = 1
	delay.update()
	t:tdeq(updated_hashes, {"selected"})

	delay.set_timer(function()
		return 0
	end)
end

---@param t testing.T
function test.score_items_event_is_forwarded_to_ui_observers(t)
	local replayBase = ReplayBase()
	local selector = createSelector("chartmetas", replayBase)
	selector.store.items = {{id = 12, accuracy = 1}}

	local received
	selector:onChanged(function(event)
		received = event
	end)

	selector:receive({type = "score_items_changed", items = selector.store.items})

	t:tdeq(received, {type = "score_items_changed", items = selector.store.items})
	t:eq(selector.chartplay, selector.store.items[1])
	t:eq(selector.state.chartplayIndex, 1)
	t:eq(selector.state.scoreId, 12)
end

---@param t testing.T
function test.score_store_ignores_stale_provider_result(t)
	local configModel = createConfigModel("chartmetas")
	local store
	local localProvider = {
		getChartplaysForChartmeta = function()
			store.requestId = 2
			return {{id = 1, accuracy = 1}}
		end,
		getChartplaysForChartdiff = function()
			return {}
		end,
	}
	local onlineProvider = {
		getChartplaysForChartmeta = function()
			return {}
		end,
		getChartplaysForChartdiff = function()
			return {}
		end,
	}
	store = ScoreStore(configModel, localProvider, onlineProvider)

	local changed_count = 0
	store:onChanged(function()
		changed_count = changed_count + 1
	end)

	store:updateItemsAsync({hash = "old", index = 1}, "chartmeta", 1)

	t:eq(store:count(), 0)
	t:eq(changed_count, 0)
end

return test
