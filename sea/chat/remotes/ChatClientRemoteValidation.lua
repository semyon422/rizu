local class = require("class")

---@class sea.chat.remotes.ChatClientRemoteValidation: sea.chat.remotes.ChatClientRemote
---@operator call: sea.chat.remotes.ChatClientRemoteValidation
local ChatClientRemoteValidation = class()

---@param remote sea.chat.remotes.ChatClientRemote
function ChatClientRemoteValidation:new(remote)
	self.remote = assert(remote)
end

---@param msg sea.chat.ChatMessage
function ChatClientRemoteValidation:addMessage(msg)
	assert(type(msg) == "table")
	assert(type(msg.user_id) == "number")
	assert(type(msg.user_name) == "string")
	assert(type(msg.text) == "string")
	assert(type(msg.time) == "number")
	assert(msg.role == nil or msg.role == "admin" or msg.role == "donator")
	self.remote:addMessage(msg)
end

return ChatClientRemoteValidation
