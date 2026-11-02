local class = require("class")
local OnlineClientRemote = require("rizu.online.remotes.OnlineClientRemote")
local MultiplayerClientRemote = require("sea.multi.remotes.MultiplayerClientRemote")
local ChatClientRemote = require("sea.chat.remotes.ChatClientRemote")

---@class sea.ClientRemote: sea.IClientRemoteContext
---@field multiplayer sea.MultiplayerClientRemote
---@field chat sea.chat.remotes.ChatClientRemote
---@operator call: sea.ClientRemote
local ClientRemote = class()

---@param client rizu.OnlineClient
---@param library rizu.library.Library
---@param multipalyer_client sea.MultiplayerClient
---@param chat_client sea.chat.ChatClient
function ClientRemote:new(client, library, multipalyer_client, chat_client)
	self.client = OnlineClientRemote(client)
	self.multiplayer = MultiplayerClientRemote(multipalyer_client)
	self.chat = ChatClientRemote(chat_client)
	self.compute_data_provider = library.computeDataProvider
end

---@param ... any
function ClientRemote:print(...)
	print(...)
end

---@return number
function ClientRemote:getRandomNumber()
	return math.random()
end

return ClientRemote
