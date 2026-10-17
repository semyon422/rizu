local class = require("class")
local ReplayBase = require("sea.replays.ReplayBase")
local Settings = require("rizu.config.Settings")

---@class rizu.select.ISelectionReplayBaseApplier
---@field copySelectionFields fun(self: rizu.select.ISelectionReplayBaseApplier, chartview: rizu.library.LocatedChartview, targetReplayBase: sea.ReplayBase): boolean
---@field buildSelectionReplayBase fun(self: rizu.select.ISelectionReplayBaseApplier, chartview: rizu.library.LocatedChartview): sea.ReplayBase, boolean
---@field apply fun(self: rizu.select.ISelectionReplayBaseApplier, chartview: rizu.library.LocatedChartview): boolean

---@class rizu.select.services.SelectionReplayBaseApplier: rizu.select.ISelectionReplayBaseApplier
---@operator call: rizu.select.services.SelectionReplayBaseApplier
local SelectionReplayBaseApplier = class()

---@param settings rizu.config.Config
---@param replayBase sea.ReplayBase
function SelectionReplayBaseApplier:new(settings, replayBase)
	self.settings = settings
	self.replayBase = replayBase
end

---@param chartview rizu.library.LocatedChartview
---@param targetReplayBase sea.ReplayBase
---@return boolean applied
function SelectionReplayBaseApplier:copySelectionFields(chartview, targetReplayBase)
	local secondary_mode = self.settings:getChoice(Settings.keys.select.secondary_mode)
	if secondary_mode == "chartfile_sets" or secondary_mode == "chartfiles" or secondary_mode == "chartmetas" then
		return false
	end

	targetReplayBase.modifiers = chartview.modifiers or {}
	targetReplayBase.rate = chartview.rate or 1
	targetReplayBase.mode = chartview.mode or "mania"

	if secondary_mode == "chartdiffs" then
		return true
	end

	targetReplayBase.nearest = chartview.nearest or false
	targetReplayBase.tap_only = chartview.tap_only or false
	targetReplayBase.timings = chartview.timings
	targetReplayBase.subtimings = chartview.subtimings
	targetReplayBase.healths = chartview.healths
	targetReplayBase.columns_order = chartview.columns_order
	targetReplayBase.custom = chartview.custom or false
	targetReplayBase.const = chartview.const or false
	targetReplayBase.rate_type = chartview.rate_type or "linear"

	return true
end

---@param chartview rizu.library.LocatedChartview
---@return sea.ReplayBase replayBase
---@return boolean applied
function SelectionReplayBaseApplier:buildSelectionReplayBase(chartview)
	local replayBase = ReplayBase()
	replayBase:importReplayBase(self.replayBase)

	return replayBase, self:copySelectionFields(chartview, replayBase)
end

---@param chartview rizu.library.LocatedChartview
---@return boolean applied
function SelectionReplayBaseApplier:apply(chartview)
	local replayBase, applied = self:buildSelectionReplayBase(chartview)
	if applied then
		self.replayBase:importReplayBase(replayBase)
	end
	return applied
end

return SelectionReplayBaseApplier
