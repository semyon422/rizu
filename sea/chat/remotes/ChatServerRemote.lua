local class = require("class")

---@class sea.chat.remotes.ChatServerRemote: sea.IServerRemoteContext
---@operator call: sea.chat.remotes.ChatServerRemote
local ChatServerRemote = class()

---@param chat sea.chat.Chat
function ChatServerRemote:new(chat)
	self.chat = chat
end

---@param text string
---@return true?
---@return string?
function ChatServerRemote:sendMessage(text)
	local msg, err = self.chat:send(self.user, text)
	if not msg then
		return nil, err
	end
	return true
end

return ChatServerRemote
