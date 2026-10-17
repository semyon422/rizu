--- Tests for bancho chat ChatManager.

local ChatManager = require("bancho.chat.ChatManager")
local ChannelCollection = require("bancho.model.ChannelCollection")
local Privileges = require("bancho.constants.Privileges")
local Player = require("bancho.model.Player")

local test = {}

function test.create_channel(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")

	t:assert(cm:getChannel("#test") ~= nil)
	t:eq(ch.name, "#test")
end

function test.join_channel(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")
	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	t:eq(cm:join(ch, player), true)
	t:assert(ch:contains(player))
end

function test.leave_channel(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")
	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	cm:join(ch, player)
	cm:leave(ch, player)

	t:assert(not ch:contains(player))
end

function test.send_message(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")

	local sender = Player(1, "Sender", Privileges.UNRESTRICTED)
	local receiver = Player(2, "Receiver", Privileges.UNRESTRICTED)

	cm:join(ch, sender)
	cm:join(ch, receiver)

	t:eq(cm:send(ch, sender, "Hello!"), true)

	-- Receiver should have a packet
	local data = receiver:dequeue()
	t:assert(data ~= nil)
end

function test.send_private(t)
	local cm = ChatManager(ChannelCollection())

	local sender = Player(1, "Sender", Privileges.UNRESTRICTED)
	local target = Player(2, "Target", Privileges.UNRESTRICTED)

	t:eq(cm:sendPrivate(sender, target, "DM"), true)

	-- Target should have a packet
	t:assert(target:dequeue() ~= nil)
	-- Sender should have echo
	t:assert(sender:dequeue() ~= nil)
end

function test.send_private_to_nonexistent(t)
	local cm = ChatManager(ChannelCollection())

	local sender = Player(1, "Sender", Privileges.UNRESTRICTED)

	t:eq(cm:sendPrivate(sender, nil, "DM"), false)
end

function test.send_bot(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")

	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	cm:join(ch, player)
	cm:sendBot(ch, "Bot message")

	-- Player should have a packet
	t:assert(player:dequeue() ~= nil)
end

function test.kick(t)
	local cm = ChatManager(ChannelCollection())
	local ch = cm:createChannel("#test", "Test channel")

	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	cm:join(ch, player)
	cm:kick(ch, player)

	t:assert(not ch:contains(player))
end

function test.auto_join(t)
	local cm = ChatManager(ChannelCollection())
	cm:createChannel("#general", "General", nil, nil, true, false)
	cm:createChannel("#staff", "Staff", Privileges.STAFF, Privileges.STAFF, false, false)

	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	cm:autoJoin(player)

	local ch = cm:getChannel("#general")
	t:assert(ch:contains(player))
end

function test.get_channels(t)
	local cm = ChatManager(ChannelCollection())
	cm:createChannel("#a", "A")
	cm:createChannel("#b", "B")

	local channels = cm:getChannels()
	t:eq(#channels, 2)
end

function test.send_login_messages(t)
	local cm = ChatManager(ChannelCollection())
	cm:createChannel("#general", "General", nil, nil, true, false)

	local player = Player(1, "TestUser", Privileges.UNRESTRICTED)

	cm:sendLoginMessages(player, {2, 3})

	-- Player should have multiple packets
	t:assert(#player._packet_queue > 0)
end

return test
