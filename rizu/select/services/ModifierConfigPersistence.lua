local class = require("class")

---@class rizu.select.IModifierConfigPersistence
---@field loadReplayBase fun(self: rizu.select.IModifierConfigPersistence, configurator: rizu.gameplay.ReplayBaseConfigurator)
---@field saveReplayBase fun(self: rizu.select.IModifierConfigPersistence, configurator: rizu.gameplay.ReplayBaseConfigurator)

---@class rizu.select.services.ModifierConfigPersistence: rizu.select.IModifierConfigPersistence
---@operator call: rizu.select.services.ModifierConfigPersistence
local ModifierConfigPersistence = class()

---@param configModel sphere.ConfigModel
function ModifierConfigPersistence:new(configModel)
	self.configModel = configModel
end

---@param configurator rizu.gameplay.ReplayBaseConfigurator
function ModifierConfigPersistence:loadReplayBase(configurator)
	self.configModel:write()
	configurator:importReplayBase(self.configModel.configs.play)
end

---@param configurator rizu.gameplay.ReplayBaseConfigurator
function ModifierConfigPersistence:saveReplayBase(configurator)
	configurator:exportReplayBase(self.configModel.configs.play)
	self.configModel:write()
end

return ModifierConfigPersistence
