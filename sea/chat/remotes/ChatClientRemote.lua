local class = require("class")

---@class sea.chat.remotes.ChatClientRemote: sea.IClientRemoteContext
---@operator call: sea.chat.remotes.ChatClientRemote
local ChatClientRemote = class()

---@param client sea.chat.ChatClient
function ChatClientRemote:new(client)
	self.client = client
end

---@param msg sea.chat.ChatMessage
function ChatClientRemote:addMessage(msg)
	self.client:addMessage(msg)
end

return ChatClientRemote
