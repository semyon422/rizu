local ReplayBase = require("sea.replays.ReplayBase")
local ModifierCoordinator = require("rizu.select.ModifierCoordinator")

local test = {}

---@param chartview table?
---@param calls string[]
---@param is_changed boolean?
---@param candidateReplayBase sea.ReplayBase?
---@return rizu.select.ModifierCoordinator
local function createCoordinator(chartview, calls, is_changed, candidateReplayBase)
	local chartSelector = {
		chartview = chartview,
		isPlayableChartview = function(_, item)
			return item and item.inputmode ~= nil
		end,
	}
	local scoreSelector = {
		buildSelectionReplayBase = function()
			table.insert(calls, "selection-replay-base")
			local replayBase = candidateReplayBase or ReplayBase()
			replayBase.rate = 1.25
			return replayBase, true
		end,
	}
	local modifierSelectModel = {
		isChanged = function()
			return is_changed == true
		end,
	}
	local configModel = {
		configs = {
			play = {},
		},
		write = function() end,
	}
	local multiplayerModel = {
		client = {
			updateReplayBase = function()
				table.insert(calls, "multiplayer")
			end,
		},
	}
	local replayBase = ReplayBase()
	replayBase.columns_order = {1, 2, 3, 4}
	local previewModel = {
		setRate = function(_, rate)
			table.insert(calls, "preview-rate:" .. tostring(rate))
		end,
	}

	return ModifierCoordinator(
		chartSelector,
		scoreSelector,
		modifierSelectModel,
		configModel,
		multiplayerModel,
		replayBase,
		previewModel
	)
end

---@param t testing.T
function test.provisional_chartview_does_not_apply_modifier_meta(t)
	local calls = {}
	local coordinator = createCoordinator({chartfile_id = 1}, calls)

	t:has_not_error(function()
		coordinator:applyModifierMeta(true)
	end)

	t:tdeq(calls, {})
	t:eq(coordinator.replayBase.columns_order, nil)
end

---@param t testing.T
function test.playable_chartview_applies_modifier_meta(t)
	local calls = {}
	local coordinator = createCoordinator({inputmode = "4key"}, calls)

	coordinator:applySelectionModifierMeta()

	t:tdeq(calls, {
		"selection-replay-base",
		"preview-rate:1.25",
	})
	t:eq(coordinator.replayBase.rate, 1.25)
end

---@param t testing.T
function test.selection_modifier_meta_does_not_sync_multiplayer(t)
	local calls = {}
	local coordinator = createCoordinator({inputmode = "4key"}, calls)

	coordinator:applySelectionModifierMeta()

	t:tdeq(calls, {
		"selection-replay-base",
		"preview-rate:1.25",
	})
end

---@param t testing.T
function test.manual_modifier_change_syncs_multiplayer_without_selection_import(t)
	local calls = {}
	local coordinator = createCoordinator({inputmode = "4key"}, calls, true)

	coordinator:update()

	t:tdeq(calls, {
		"multiplayer",
		"preview-rate:1",
	})
end

---@param t testing.T
function test.selection_candidate_is_validated_before_global_import(t)
	local calls = {}
	local candidateReplayBase = ReplayBase()
	candidateReplayBase.columns_order = {1, 2, 3}
	local coordinator = createCoordinator({inputmode = "4key"}, calls, nil, candidateReplayBase)

	coordinator:applySelectionModifierMeta()

	t:eq(candidateReplayBase.columns_order, nil)
	t:eq(coordinator.replayBase.columns_order, nil)
end

return test
