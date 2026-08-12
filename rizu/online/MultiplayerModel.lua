local class = require("class")
local delay = require("delay")
local icc_co = require("icc.co")

---@class rizu.MultiplayerChartSetStore
---@field get fun(self: rizu.MultiplayerChartSetStore, index: integer): rizu.library.LocatedChartview?

---@class rizu.MultiplayerChartSelector: rizu.select.ChartSelector
---@field chartSetStore rizu.MultiplayerChartSetStore

---@class rizu.MultiplayerRoom: sea.Room
---@field notechart {osuSetId: integer?}

---@class rizu.MultiplayerClient: sea.MultiplayerClient
---@field getMyRoom fun(self: rizu.MultiplayerClient): rizu.MultiplayerRoom?

---@class rizu.MultiplayerDownload
---@field id integer
---@field status string

---@class rizu.MultiplayerModel
---@operator call: rizu.MultiplayerModel
---@field chartSelector rizu.MultiplayerChartSelector
---@field client rizu.MultiplayerClient
---@field chartview rizu.library.LocatedChartview?
---@field downloadingBeatmap rizu.MultiplayerDownload?
local MultiplayerModel = class()

---@param library rizu.library.Library
---@param rhythm_engine rizu.RhythmEngine
---@param configModel sphere.ConfigModel
---@param chartSelector rizu.MultiplayerChartSelector
---@param onlineModel rizu.OnlineModel
---@param dlcManager rizu.dlc.DlcManager
---@param replayBase sea.ReplayBase
---@param multiplayer_client rizu.MultiplayerClient
function MultiplayerModel:new(library, rhythm_engine, configModel, chartSelector, onlineModel, dlcManager, replayBase, multiplayer_client)
	self.library = library
	self.rhythm_engine = rhythm_engine
	self.configModel = configModel
	self.chartSelector = chartSelector
	self.onlineModel = onlineModel
	self.dlcManager = dlcManager
	self.replayBase = replayBase

	self.sea_client = onlineModel.sea_client
	self.remote = self.sea_client.remote
	self.task_handler = self.sea_client.task_handler

	self.client = multiplayer_client

	self.status = "disconnected"
end

function MultiplayerModel:load()
	self.stopRefresh = delay.every(0.5, self.refreshAsync, self)
end

function MultiplayerModel:unload()
	self.stopRefresh()
end

function MultiplayerModel:refreshAsync()
	self.status = self:getStatus()
	if not self.sea_client.connected then
		return
	end

	local user = self.onlineModel:getUser()
	self.client.user_id = user and user.id
	self.client:refreshAsync()

	-- disabled because not implemented yet
	-- local chartplay_computed = self.rhythm_engine:getChartplayComputed(true)
	-- self.remote.multiplayer:setChartplayComputed(chartplay_computed)
end

function MultiplayerModel:connect()
end

function MultiplayerModel:disconnect()
end

function MultiplayerModel:update()
end

function MultiplayerModel:getStatus()
	if self.sea_client.connected then
		return "connected"
	else
		return "disconnected"
	end
end

function MultiplayerModel:selectChart()
	local chartSelector = self.chartSelector

	local room = self.client:getMyRoom()
	if not room then
		return
	end

	local hash = room.chartmeta_key.hash
	local index = room.chartmeta_key.index

	print("find", hash, index)
	chartSelector:findChartmeta(hash, index)

	chartSelector:setLock(false)

	self.downloadingBeatmap = nil
	local chartview = chartSelector.chartSetStore:get(1)
	if chartview then
		self.chartview = chartview
		chartSelector:setConfig(chartview)
		chartSelector:refresh(true)
		self.remote.multiplayer:setChartFound(true)
		return
	end
	chartSelector:setConfig({
		chartfile_set_id = 0,
		chartfile_id = 0,
		chartmeta_id = 0,
		chartdiff_id = 0,
		chartplay_id = 0,
	})
	self.chartview = nil
	chartSelector:refresh(true)
	self.remote.multiplayer:setChartFound(false)
end

---@param self rizu.MultiplayerModel
local function download_note_chart(self)
	local room = self.client:getMyRoom()
	if not room then return end

	local setId = room.notechart.osuSetId
	if self.downloadingBeatmap or not setId then
		return
	end

	self.downloadingBeatmap = {
		id = setId,
		status = "",
	}
	self.dlcManager:download(setId, "chart")
	self.downloadingBeatmap.status = "done"
	self.remote.multiplayer:setChartFound(false)

	self.library:computeLocationAsync("downloads", 1)
	self:selectChart()
end

MultiplayerModel.downloadNoteChart = icc_co.callwrap(download_note_chart)

return MultiplayerModel
