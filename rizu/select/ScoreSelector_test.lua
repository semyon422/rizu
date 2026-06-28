local Healths = require("sea.chart.Healths")
local delay = require("delay")
local ReplayBase = require("sea.replays.ReplayBase")
local ScoreSelector = require("rizu.select.ScoreSelector")
local SelectionState = require("rizu.select.SelectionState")
local ScoreStore = require("rizu.select.stores.ScoreStore")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")

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

local function createChartview()
	return {
		modifiers = {{id = 1, value = 2}},
		rate = 1.5,
		mode = "mania",
		nearest = true,
		tap_only = true,
		timings = Timings("osuod", 8),
		subtimings = Subtimings("scorev", 1),
		healths = Healths("simple", 10),
		columns_order = {4, 3, 2, 1},
		custom = true,
		const = true,
		rate_type = "exp",
	}
end

---@param t testing.T
function test.coarse_modes_do_not_update_replay_base(t)
	for _, mode in ipairs({"chartfile_sets", "chartfiles", "chartmetas"}) do
		local replayBase = ReplayBase()
		replayBase.rate = 0.75

		createSelector(mode, replayBase):updateReplayBase(createChartview())

		t:eq(replayBase.rate, 0.75, mode)
		t:tdeq(replayBase.modifiers, {}, mode)
		t:eq(replayBase.nearest, false, mode)
	end
end

---@param t testing.T
function test.chartdiff_mode_updates_only_diff_key_fields(t)
	local replayBase = ReplayBase()

	createSelector("chartdiffs", replayBase):updateReplayBase(createChartview())

	t:tdeq(replayBase.modifiers, {{id = 1, value = 2}})
	t:eq(replayBase.rate, 1.5)
	t:eq(replayBase.mode, "mania")

	t:eq(replayBase.nearest, false)
	t:eq(replayBase.tap_only, false)
	t:eq(replayBase.timings, Timings("sphere"))
	t:eq(replayBase.subtimings, nil)
	t:eq(replayBase.healths, nil)
	t:eq(replayBase.columns_order, nil)
	t:eq(replayBase.custom, false)
	t:eq(replayBase.const, false)
	t:eq(replayBase.rate_type, "linear")
end

---@param t testing.T
function test.chartplays_mode_updates_chartplay_base_fields(t)
	local replayBase = ReplayBase()

	createSelector("chartplays", replayBase):updateReplayBase(createChartview())

	t:tdeq(replayBase.modifiers, {{id = 1, value = 2}})
	t:eq(replayBase.rate, 1.5)
	t:eq(replayBase.mode, "mania")
	t:eq(replayBase.nearest, true)
	t:eq(replayBase.tap_only, true)
	t:eq(replayBase.timings, Timings("osuod", 8))
	t:eq(replayBase.subtimings, Subtimings("scorev", 1))
	t:eq(replayBase.healths, Healths("simple", 10))
	t:tdeq(replayBase.columns_order, {4, 3, 2, 1})
	t:eq(replayBase.custom, true)
	t:eq(replayBase.const, true)
	t:eq(replayBase.rate_type, "exp")
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

	store:updateItemsAsync({hash = "old", index = 1}, false, 1)

	t:eq(store:count(), 0)
	t:eq(changed_count, 0)
end

return test
