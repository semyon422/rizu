local class = require("class")

---@class sea.chat.remotes.ChatServerRemoteValidation: sea.chat.remotes.ChatServerRemote
---@operator call: sea.chat.remotes.ChatServerRemoteValidation
local ChatServerRemoteValidation = class()

---@param remote sea.chat.remotes.ChatServerRemote
function ChatServerRemoteValidation:new(remote)
	self.remote = remote
end

---@param text string
---@return true?
---@return string?
function ChatServerRemoteValidation:sendMessage(text)
	assert(type(text) == "string")
	return self.remote:sendMessage(text)
end

return ChatServerRemoteValidation
