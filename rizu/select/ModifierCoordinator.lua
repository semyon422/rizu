local class = require("class")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")
local InputMode = require("chart.core.InputMode")

---@class rizu.select.ModifierCoordinator
---@operator call: rizu.select.ModifierCoordinator
local ModifierCoordinator = class()

---@param chartSelector rizu.select.ChartSelector
---@param scoreSelector rizu.select.ScoreSelector
---@param modifierSelectModel sphere.ModifierSelectModel
---@param configModel sphere.ConfigModel
---@param multiplayerModel sphere.MultiplayerModel
---@param replayBase sea.ReplayBase
---@param previewModel rizu.preview.PreviewModel
function ModifierCoordinator:new(
	chartSelector,
	scoreSelector,
	modifierSelectModel,
	configModel,
	multiplayerModel,
	replayBase,
	previewModel
)
	self.chartSelector = chartSelector
	self.scoreSelector = scoreSelector
	self.modifierSelectModel = modifierSelectModel
	self.configModel = configModel
	self.multiplayerModel = multiplayerModel
	self.replayBase = replayBase
	self.previewModel = previewModel
	
	self.state = ModifiersMetaState()
end

function ModifierCoordinator:load()
	self.configModel:write()
	self.replayBase:importReplayBase(self.configModel.configs.play)
	self.modifierSelectModel:updateAdded()
	
	self:applySelectionModifierMeta()
end

function ModifierCoordinator:unload()
	self.replayBase:exportReplayBase(self.configModel.configs.play)
	self.configModel:write()
end

function ModifierCoordinator:applySelectionModifierMeta()
	local chartview = self.chartSelector.chartview
	if not self.chartSelector:isPlayableChartview(chartview) then
		self.replayBase.columns_order = nil
		return
	end

	local replayBase = self.scoreSelector:buildSelectionReplayBase(chartview)
	self:applyModifierMetaToReplayBase(replayBase, chartview)
	self.replayBase:importReplayBase(replayBase)
end

function ModifierCoordinator:applyManualModifierMeta()
	self:applyModifierMetaToCurrentReplayBase()
end

---@param fromSelection boolean?
function ModifierCoordinator:applyModifierMeta(fromSelection)
	if fromSelection then
		self:applySelectionModifierMeta()
	else
		self:applyManualModifierMeta()
	end
end

function ModifierCoordinator:applyModifierMetaToCurrentReplayBase()
	local chartview = self.chartSelector.chartview
	if not self.chartSelector:isPlayableChartview(chartview) then
		self.replayBase.columns_order = nil
		return
	end

	self:applyModifierMetaToReplayBase(self.replayBase, chartview)
end

---@param replayBase sea.ReplayBase
---@param chartview rizu.library.LocatedChartview
function ModifierCoordinator:applyModifierMetaToReplayBase(replayBase, chartview)
	self.state.inputMode = InputMode()
	self.state.custom = false

	self.previewModel:setRate(replayBase.rate)
	self.state.inputMode:set(chartview.inputmode)
	self.state:resetOrder()

	ModifierModel:applyMeta(replayBase.modifiers, self.state)

	if replayBase.columns_order and #replayBase.columns_order ~= self.state.inputMode:getColumns() then
		replayBase.columns_order = nil
	end
end

function ModifierCoordinator:syncManualReplayBaseToMultiplayer()
	self.multiplayerModel.client:updateReplayBase()
end

function ModifierCoordinator:update()
	if self.modifierSelectModel:isChanged() then
		self:syncManualReplayBaseToMultiplayer()
		self:applyManualModifierMeta()
	end
end

return ModifierCoordinator
