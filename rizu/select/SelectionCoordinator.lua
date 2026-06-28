local class = require("class")

---@class rizu.select.SelectionCoordinator
---@operator call: rizu.select.SelectionCoordinator
local SelectionCoordinator = class()

---@param chartSelector rizu.select.ChartSelector
---@param scoreSelector rizu.select.ScoreSelector
---@param collectionSelector rizu.select.CollectionSelector
---@param backgroundModel sphere.BackgroundModel
---@param previewModel rizu.preview.PreviewModel
---@param windowModel sphere.WindowModel
function SelectionCoordinator:new(
	chartSelector,
	scoreSelector,
	collectionSelector,
	backgroundModel,
	previewModel,
	windowModel
)
	self.chartSelector = chartSelector
	self.scoreSelector = scoreSelector
	self.collectionSelector = collectionSelector
	self.backgroundModel = backgroundModel
	self.previewModel = previewModel
	self.windowModel = windowModel

	self.chartSelector.state.onChanged:add({
		---@param event rizu.select.SelectionStateEvent
		receive = function(_, event)
			if event.type == "selection" and event.level == 2 then
				---@cast event rizu.select.SelectionEvent
				self.scoreSelector:setChart(self.chartSelector.chartview)
			end
		end
	})

	self.chartSelector.onChanged:add(self.scoreSelector)

	self.collectionSelector.onChanged:add({
		---@param event rizu.select.CollectionSelectorEvent
		receive = function(_, event)
			if event.type == "collection_changed" then
				---@cast event rizu.select.CollectionChangedEvent
				self.chartSelector:noDebounceRefresh(not event.path_changed)
			end
		end
	})
end

function SelectionCoordinator:load()
	self.chartSelector:setLock(false)
	self.chartSelector:load()
	self.previewModel:load()
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
	self.windowModel:setVsyncOnSelect(true)

	local chartSelector = self.chartSelector
	if chartSelector:isChanged() then
		self.backgroundModel:setBackgroundPath(chartSelector:getBackgroundPath())
		local audio_path, preview_time, mode = chartSelector:getAudioPathPreview()
		if audio_path or not chartSelector.chartview then
			self.previewModel:setAudioPathPreview(audio_path, preview_time, mode, chartSelector.chartview)
		end
		if applyModifierMeta then
			applyModifierMeta(true)
		end
	end
end

return SelectionCoordinator
