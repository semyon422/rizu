local class = require("class")
local thread = require("thread")

---@class rizu.select.SelectionCoordinator
---@operator call: rizu.select.SelectionCoordinator
local SelectionCoordinator = class()

---@param chartSelector rizu.select.ChartSelector
---@param scoreSelector rizu.select.ScoreSelector
---@param collectionSelector rizu.select.CollectionSelector
---@param backgroundModel sphere.BackgroundModel
---@param previewModel rizu.preview.PreviewModel
---@param catalog rizu.library.RemoteCatalogLoader?
function SelectionCoordinator:new(
	chartSelector,
	scoreSelector,
	collectionSelector,
	backgroundModel,
	previewModel,
	catalog
)
	self.catalog = catalog
	self.chartSelector = chartSelector
	self.scoreSelector = scoreSelector
	self.collectionSelector = collectionSelector
	self.backgroundModel = backgroundModel
	self.previewModel = previewModel

	self.chartSelector:onChanged(self.scoreSelector)

	self.collectionSelector:onChanged(function(event)
		if event.type == "collection_selection_changed" then
			self.chartSelector:noDebounceRefresh(not event.query_scope_changed)
		end
	end)
end

function SelectionCoordinator:load()
	self.chartSelector:setLock(false)
	self.chartSelector:load()
	-- Keeps the catalog of a player who stays online up to date.
	if self.catalog and self.chartSelector.config.online then
		thread.coro(self.syncOnline)(self)
	end
end

---Brings the remote catalog into the library, or up to date, and lists the charts again. Yields.
---@return boolean ok
---@return string? err
function SelectionCoordinator:syncOnline()
	local location_id, err = self.catalog:sync(self.chartSelector.library)
	self.collectionSelector:load()
	self.chartSelector:noDebounceRefresh()
	return location_id ~= nil, err
end

---Starts the previews of the selected chart, which then follow the selection. Does nothing while they play.
---The user interface decides when: the game only stops them, when a chart is loaded to be played.
function SelectionCoordinator:startPreview()
	if self.previewModel.active then return end
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
