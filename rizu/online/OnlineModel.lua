local class = require("class")
local AuthManager = require("rizu.online.AuthManager")

---@class rizu.OnlineModel
---@operator call: rizu.OnlineModel
local OnlineModel = class()

---@param configModel sphere.ConfigModel
---@param sea_client rizu.SeaClient
function OnlineModel:new(configModel, sea_client)
	self.configModel = configModel
	self.sea_client = sea_client
	self.authManager = AuthManager(sea_client, configModel)
end

function OnlineModel:getUser()
	return self.configModel.configs.online.user
end

return OnlineModel
