local ModifierCoordinator = require("rizu.select.ModifierCoordinator")

local test = {}

---@param chartview table?
---@param calls string[]
---@return rizu.select.ModifierCoordinator
local function createCoordinator(chartview, calls)
	local chartSelector = {
		chartview = chartview,
		isPlayableChartview = function(_, item)
			return item and item.inputmode ~= nil
		end,
	}
	local scoreSelector = {
		updateReplayBase = function()
			table.insert(calls, "replay-base")
		end,
	}
	local modifierSelectModel = {
		isChanged = function()
			return false
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
	local replayBase = {
		modifiers = {},
		rate = 1,
		columns_order = {1, 2, 3, 4},
	}
	local previewModel = {
		setRate = function()
			table.insert(calls, "preview-rate")
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

	coordinator:applyModifierMeta(true)

	t:tdeq(calls, {
		"replay-base",
		"preview-rate",
	})
end

return test
