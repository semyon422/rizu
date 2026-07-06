local class = require("class")
local OnlineClientRemoteValidation = require("rizu.online.remotes.OnlineClientRemoteValidation")
local ComputeDataProviderRemoteValidation = require("sea.compute.remotes.ComputeDataProviderRemoteValidation")
local MultiplayerClientRemoteValidation = require("sea.multi.remotes.MultiplayerClientRemoteValidation")

---@class sea.ClientRemoteValidation: sea.ClientRemote
---@field multiplayer sea.MultiplayerClientRemoteValidation
---@operator call: sea.ClientRemoteValidation
local ClientRemoteValidation = class()

---@param remote sea.ClientRemote
function ClientRemoteValidation:new(remote)
	self.remote = remote
end

function ClientRemoteValidation:__index(k)
	local v = ClientRemoteValidation[k]
	if v ~= nil then return v end

	if k == "client" then
		self.client = OnlineClientRemoteValidation(self.remote.client)
		return self.client
	elseif k == "multiplayer" then
		self.multiplayer = MultiplayerClientRemoteValidation(self.remote.multiplayer)
		return self.multiplayer
	elseif k == "compute_data_provider" then
		self.compute_data_provider = ComputeDataProviderRemoteValidation(self.remote.compute_data_provider)
		return self.compute_data_provider
	end
end

---@param ... any
function ClientRemoteValidation:print(...)
	return self.remote:print(...)
end

---@return number
function ClientRemoteValidation:getRandomNumber()
	local res = self.remote:getRandomNumber()
	assert(type(res) == "number")
	return res
end

return ClientRemoteValidation
