local class = require("class")
local icc_co = require("icc.co")
local Observable = require("Observable")
local Profanity = require("sea.chat.Profanity")

---@class sea.chat.ChatClient.MessageEvent
---@field type "message"
---@field message sea.chat.ChatMessage

---@class sea.chat.ChatClient
---@operator call: sea.chat.ChatClient
local ChatClient = class()

-- Oldest messages are dropped past this so a long session doesn't grow forever.
ChatClient.max_messages = 200

---@param server_remote sea.ServerRemote?
---@param censor (fun(): boolean)? whether to censor profanity in messages arriving now, yes by default
function ChatClient:new(server_remote, censor)
	self.server_remote = server_remote
	self.censor = censor or function() return true end
	self.observable = Observable()
	---@type sea.chat.ChatMessage[]
	self.messages = {}
end

---@param observer {receive: fun(self: table, event: sea.chat.ChatClient.MessageEvent)}|fun(event: sea.chat.ChatClient.MessageEvent)
---@return util.Observer
function ChatClient:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function ChatClient:offChanged(observer)
	return self.observable:remove(observer)
end

---@param msg sea.chat.ChatMessage
function ChatClient:addMessage(msg)
	-- shortcut: censored on arrival, so turning the option off only affects new messages; keep the raw text if that matters.
	if self.censor() then
		msg.text = Profanity.censor(msg.text)
	end
	table.insert(self.messages, msg)
	if #self.messages > self.max_messages then
		table.remove(self.messages, 1)
	end
	self.observable:send({type = "message", message = msg})
end

---@async
---@param text string
---@return true?
---@return string?
function ChatClient:sendMessageAsync(text)
	return self.server_remote.chat:sendMessage(text)
end

ChatClient.sendMessage = icc_co.callwrap(ChatClient.sendMessageAsync)

return ChatClient
