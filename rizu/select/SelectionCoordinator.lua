local class = require("class")

---@class rizu.select.SelectionCoordinator
---@operator call: rizu.select.SelectionCoordinator
local SelectionCoordinator = class()

---@param chartSelector rizu.select.ChartSelector
---@param scoreSelector rizu.select.ScoreSelector
---@param collectionSelector rizu.select.CollectionSelector
---@param backgroundModel sphere.BackgroundModel
---@param previewModel rizu.preview.PreviewModel
function SelectionCoordinator:new(
	chartSelector,
	scoreSelector,
	collectionSelector,
	backgroundModel,
	previewModel
)
	self.chartSelector = chartSelector
	self.scoreSelector = scoreSelector
	self.collectionSelector = collectionSelector
	self.backgroundModel = backgroundModel
	self.previewModel = previewModel

	self.chartSelector.state:onChanged(function(event)
		if event.type == "selection_changed" and event.level == 2 then
			self.scoreSelector:setChart(self.chartSelector.chartview)
		end
	end)

	self.chartSelector:onChanged(self.scoreSelector)
	self.chartSelector:onChanged(function(event)
		if event.type == "chartview_changed" and self.chartSelector:isPlayableChartview(event.chartview) then
			self:activatePreview()
		end
	end)

	self.collectionSelector:onChanged(function(event)
		if event.type == "collection_selection_changed" then
			self.chartSelector:noDebounceRefresh(not event.query_scope_changed)
		end
	end)
end

function SelectionCoordinator:load()
	self.chartSelector:setLock(false)
	self.chartSelector:load()
end

function SelectionCoordinator:activatePreview()
	self.previewModel:load()
	self.chartSelector:setChanged()
end

function SelectionCoordinator:beginUnload()
	self.chartSelector:setLock(true)
end

function SelectionCoordinator:unload()
	self.previewModel:stop()
end

---@param applyModifierMeta? function Callback to update modifier meta
function SelectionCoordinator:update(applyModifierMeta)
	local chartSelector = self.chartSelector
	if chartSelector:isChanged() then
		local chartview = chartSelector.chartview
		local is_playable = chartSelector:isPlayableChartview(chartview)

		self.backgroundModel:setBackgroundPath(chartSelector:getBackgroundPath())
		local audio_path, preview_time, mode = chartSelector:getAudioPathPreview()
		if audio_path or not is_playable then
			self.previewModel:setAudioPathPreview(audio_path, preview_time, mode, chartview)
		end
		if applyModifierMeta then
			applyModifierMeta(true)
		end
	end
end

return SelectionCoordinator
