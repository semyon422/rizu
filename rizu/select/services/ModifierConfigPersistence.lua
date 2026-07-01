local class = require("class")

---@class rizu.select.services.ModifierConfigPersistence
---@operator call: rizu.select.services.ModifierConfigPersistence
local ModifierConfigPersistence = class()

---@param configModel sphere.ConfigModel
function ModifierConfigPersistence:new(configModel)
	self.configModel = configModel
end

---@param replayBase sea.ReplayBase
function ModifierConfigPersistence:loadReplayBase(replayBase)
	self.configModel:write()
	replayBase:importReplayBase(self.configModel.configs.play)
end

---@param replayBase sea.ReplayBase
function ModifierConfigPersistence:saveReplayBase(replayBase)
	replayBase:exportReplayBase(self.configModel.configs.play)
	self.configModel:write()
end

return ModifierConfigPersistence
