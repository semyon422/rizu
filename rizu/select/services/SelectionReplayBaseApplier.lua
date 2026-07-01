local class = require("class")

---@class rizu.select.services.SelectionReplayBaseApplier
---@operator call: rizu.select.services.SelectionReplayBaseApplier
local SelectionReplayBaseApplier = class()

---@param configModel sphere.ConfigModel
---@param replayBase sea.ReplayBase
function SelectionReplayBaseApplier:new(configModel, replayBase)
	self.configModel = configModel
	self.replayBase = replayBase
end

---@param chartview rizu.library.LocatedChartview
function SelectionReplayBaseApplier:apply(chartview)
	local config = self.configModel.configs.settings.select
	local secondary_mode = config.secondary_mode or "chartmetas"
	if secondary_mode == "chartfile_sets" or secondary_mode == "chartfiles" or secondary_mode == "chartmetas" then
		return
	end

	local replayBase = self.replayBase

	replayBase.modifiers = chartview.modifiers or {}
	replayBase.rate = chartview.rate or 1
	replayBase.mode = chartview.mode or "mania"

	if secondary_mode == "chartdiffs" then
		return
	end

	replayBase.nearest = chartview.nearest or false
	replayBase.tap_only = chartview.tap_only or false
	replayBase.timings = chartview.timings
	replayBase.subtimings = chartview.subtimings
	replayBase.healths = chartview.healths
	replayBase.columns_order = chartview.columns_order
	replayBase.custom = chartview.custom or false
	replayBase.const = chartview.const or false
	replayBase.rate_type = chartview.rate_type or "linear"
end

return SelectionReplayBaseApplier
