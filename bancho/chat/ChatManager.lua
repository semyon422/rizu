--- Chat and messaging manager.
---
--- Handles sending public/private messages, channel join/part, and bot messages.

local Channel = require("bancho.model.Channel")
local Privileges = require("bancho.constants.Privileges")
local ServerPackets = require("bancho.protocol.ServerPackets")

local class = require("class")

local function enqueue_player(players, player, data)
	if players and players._dict then
		players._dict:rpush("pq:" .. player.token, data)
	else
		player:enqueue(data)
	end
end

--- Chat manager: coordinates chat and channel operations.
---@class bancho.chat.ChatManager
---@operator call: bancho.chat.ChatManager
---@field channels bancho.model.ChannelCollection
local ChatManager = class()

function ChatManager:new(channels)
	self.channels = channels or require("bancho.model.ChannelCollection")()
	return self
end

--- Create and register a channel.
---@param name string
---@param topic string
---@param read_priv integer
---@param write_priv integer
---@param auto_join boolean
---@param instance boolean
---@return bancho.model.Channel
function ChatManager:createChannel(name, topic, read_priv, write_priv, auto_join, instance)
	local ch = Channel(name, topic, read_priv, write_priv, auto_join, instance)
	self.channels:add(ch)
	return ch
end

--- Join a channel.
---@param channel bancho.model.Channel
---@param player bancho.model.Player
---@return boolean true on success
function ChatManager:join(channel, player)
	if not channel:canRead(player.priv) then return false end

	channel:add(player)
	return true
end

--- Leave a channel.
---@param channel bancho.model.Channel
---@param player bancho.model.Player
function ChatManager:leave(channel, player)
	channel:remove(player)
end

--- Send a message to a channel.
---@param channel bancho.model.Channel
---@param player bancho.model.Player
---@param msg string
---@return boolean true on success
function ChatManager:send(channel, player, msg)
	if not channel:canWrite(player.priv) then return false end

	local data = ServerPackets.sendMessage(player.name, msg, channel.name, player.id)

	for _, p in pairs(channel.players) do
		if p.id ~= player.id then
			p:enqueue(data)
		end
	end

	return true
end

--- Send a private message.
---@param sender bancho.model.Player
---@param target bancho.model.Player
---@param msg string
---@return boolean true on success
function ChatManager:sendPrivate(sender, target, msg)
	if not target then return false end

	local data = ServerPackets.sendMessage(sender.name, msg, target.name, sender.id)
	target:enqueue(data)

	-- Echo to sender
	local echo = ServerPackets.sendMessage(sender.name, msg, sender.name, sender.id)
	sender:enqueue(echo)

	return true
end

--- Send a bot message to a channel.
---@param channel bancho.model.Channel
---@param msg string
function ChatManager:sendBot(channel, msg)
	local data = ServerPackets.sendMessage("Bot", msg, channel.name, 0)

	for _, p in pairs(channel.players) do
		p:enqueue(data)
	end
end

--- Broadcast a message to all channels a player is in.
---@param player bancho.model.Player
---@param msg string
function ChatManager:broadcastToPlayer(player, msg)
	local data = ServerPackets.sendMessage("Bot", msg, "", 0)
	player:enqueue(data)
end

--- Send a notification to a player.
---@param player bancho.model.Player
---@param msg string
function ChatManager:notify(player, msg)
	local data = ServerPackets.notification(msg)
	player:enqueue(data)
end

--- Kick a player from a channel.
---@param channel bancho.model.Channel
---@param player bancho.model.Player
function ChatManager:kick(channel, player)
	channel:remove(player)

	local data = ServerPackets.channelKick(channel.name)
	player:enqueue(data)
end

--- Get all channels.
---@return bancho.model.Channel[]
function ChatManager:getChannels()
	return self.channels:all()
end

--- Get a channel by name.
---@param name string
---@return bancho.model.Channel?
function ChatManager:getChannel(name)
	return self.channels:get(name)
end

--- Send channel info to a player.
---@param player bancho.model.Player
---@param name string
---@param topic string
---@param p_count integer
function ChatManager:sendChannelInfo(player, name, topic, p_count)
	local data = ServerPackets.channelInfo(name, topic, p_count)
	player:enqueue(data)
end

--- Auto join channels for a player.
---@param player bancho.model.Player
function ChatManager:autoJoin(player)
	for _, ch in ipairs(self:getChannels()) do
		if ch.auto_join then
			self:join(ch, player)
		end
	end
end

--- Broadcast match state update to match participants and lobby.
---@param match bancho.model.Match
---@param match_data bancho.protocol.MultiplayerMatch
---@param channels bancho.model.ChannelCollection
---@param lobby? boolean
function ChatManager:notifyMatchUpdate(match, match_data, channels, lobby)
	-- Restore match chat channel when loading matches from shared state.
	if not match.chat then
		match.chat = channels:get("#multi_" .. match.id)
	end

	local players = channels._players

	-- Send to match chat participants (with password)
	if match.chat then
		local update_pw = ServerPackets.updateMatch(match_data, true)
		for _, p in pairs(match.chat.players) do
			enqueue_player(players, p, update_pw)
		end
	end

	-- Send to lobby (without password)
	if lobby ~= false then
		local lobby_ch = channels:get("#lobby")
		if lobby_ch then
			local update_no_pw = ServerPackets.updateMatch(match_data, false)
			for _, p in pairs(lobby_ch.players) do
				enqueue_player(players, p, update_no_pw)
			end
		end
	end
end

--- Send login messages: privileges, friends list, channel info, etc.
---@param player bancho.model.Player
---@param friends integer[] friend IDs
function ChatManager:sendLoginMessages(player, friends)
	-- Send bancho privileges
	player:enqueue(ServerPackets.banchoPrivileges(player:bancho_priv()))

	-- Send friends list
	player:enqueue(ServerPackets.friendsList(friends or {}))

	-- Send protocol version
	player:enqueue(ServerPackets.protocolVersion(1))

	-- Send channel info for all channels
	for _, ch in ipairs(self:getChannels()) do
		local count = 0
		for _ in pairs(ch.players) do
			count = count + 1
		end
		self:sendChannelInfo(player, ch.real_name, ch.topic, count)
	end

	-- Channel info end marker
	player:enqueue(ServerPackets.channelInfoEnd())

	-- Auto join channels
	self:autoJoin(player)
end

return ChatManager
