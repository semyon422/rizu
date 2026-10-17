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

---@return string url
function OnlineModel:getServerUrl()
	local configs = self.configModel.configs
	local selected_url = configs.online.url
	local servers = configs.urls.servers
	for _, server in ipairs(servers) do
		if server.url == selected_url then
			return selected_url
		end
	end

	local fallback = assert(servers[1], "no online servers configured")
	configs.online.url = fallback.url
	self.configModel:write("online")
	return fallback.url
end

return OnlineModel
