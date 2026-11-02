local Chat = require("sea.chat.Chat")
local ChatClient = require("sea.chat.ChatClient")
local User = require("sea.access.User")

local test = {}

---@param sent sea.chat.ChatMessage[]
local function fake_connections(sent)
	return {
		broadcastAll = function()
			return {chat = {addMessage = function(_, msg) table.insert(sent, msg) end}}
		end,
	}
end

---@param t testing.T
function test.broadcasts_trimmed_message_from_logged_in_user(t)
	local sent = {}
	local chat = Chat(fake_connections(sent))
	local user = User()
	user.id = 5
	user.name = "nimue"

	local msg = assert(chat:send(user, "  hello  "))

	t:eq(#sent, 1)
	t:eq(sent[1], msg)
	t:eq(msg.user_id, 5)
	t:eq(msg.user_name, "nimue")
	t:eq(msg.text, "hello")
end

---@param t testing.T
function test.rejects_anon_empty_and_long_messages(t)
	local sent = {}
	local chat = Chat(fake_connections(sent))
	local user = User()
	user.id = 5
	user.name = "nimue"

	t:eq(select(2, chat:send(User(), "hi")), "not logged in")
	t:eq(select(2, chat:send(user, "   ")), "empty message")
	t:eq(select(2, chat:send(user, ("a"):rep(Chat.max_length + 1))), "message too long")
	t:eq(#sent, 0)
end

---@param t testing.T
function test.client_keeps_recent_messages_and_emits(t)
	local client = ChatClient()
	client.max_messages = 2
	local events = {}
	client:onChanged(function(event) table.insert(events, event) end)

	for i = 1, 3 do
		client:addMessage({user_id = 1, user_name = "a", text = tostring(i), time = 0})
	end

	t:eq(#client.messages, 2)
	t:eq(client.messages[1].text, "2")
	t:eq(#events, 3)
	t:eq(events[3].message.text, "3")
end

---@param t testing.T
function test.client_censors_profanity(t)
	local client = ChatClient()
	client:addMessage({user_id = 1, user_name = "a", text = "what the fuck", time = 0})
	t:eq(client.messages[1].text, "what the ***")
end

return test
