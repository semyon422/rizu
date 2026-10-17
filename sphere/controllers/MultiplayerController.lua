local class = require("class")

---@class sphere.MultiplayerController
---@operator call: sphere.MultiplayerController
local MultiplayerController = class()

---@param multiplayerModel rizu.MultiplayerModel
---@param configModel sphere.ConfigModel
---@param chartSelector rizu.select.ChartSelector
---@param replayBase sea.ReplayBase
function MultiplayerController:new(
	multiplayerModel,
	configModel,
	chartSelector,
	replayBase
)
	self.multiplayerModel = multiplayerModel
	self.configModel = configModel
	self.chartSelector = chartSelector
	self.replayBase = replayBase
end

function MultiplayerController:load()
	local mpModel = self.multiplayerModel
	mpModel:load()
end

function MultiplayerController:beginUnload()
	self.chartSelector:setLock(true)
end

function MultiplayerController:unload()
	self.multiplayerModel:unload()
end

function MultiplayerController:update()
	self.multiplayerModel:update()
end

return MultiplayerController
