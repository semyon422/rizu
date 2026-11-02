local class = require("class")

---@class sea.chat.ChatMessage
---@field user_id integer
---@field user_name string
---@field text string
---@field time integer

---One global channel. Messages are only broadcast to the connected clients, never stored.
---@class sea.chat.Chat
---@operator call: sea.chat.Chat
local Chat = class()

Chat.max_length = 500

---@param user_connections sea.UserConnections
function Chat:new(user_connections)
	self.user_connections = user_connections
end

---@param user sea.User
---@param text string
---@return sea.chat.ChatMessage?
---@return string?
function Chat:send(user, text)
	if user:isAnon() then
		return nil, "not logged in"
	end

	text = text:match("^%s*(.-)%s*$")
	if text == "" then
		return nil, "empty message"
	end
	if #text > self.max_length then
		return nil, "message too long"
	end

	---@type sea.chat.ChatMessage
	local msg = {
		user_id = user.id,
		user_name = user.name,
		text = text,
		time = os.time(),
	}

	self.user_connections:broadcastAll().chat:addMessage(msg)

	return msg
end

return Chat
