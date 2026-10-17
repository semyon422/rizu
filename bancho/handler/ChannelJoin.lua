--- Packet 63: CHANNEL_JOIN
--- Client joins a chat channel.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Channel join handler data.
---@class bancho.handler.ChannelJoinData
---@field channel_name string

--- Packet 63: CHANNEL_JOIN
---@class bancho.handler.ChannelJoin: bancho.handler.IPacketHandler
---@operator call: bancho.handler.ChannelJoin
local ChannelJoin = IPacketHandler + {}

---@return bancho.handler.ChannelJoinData
function ChannelJoin:parse(reader, bodyLen)
	return { channel_name = reader:readString() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.ChannelJoinData
function ChannelJoin:handle(server, player, data)
	local channel = server.channels:get(data.channel_name)
	if not channel then return end

	-- Check read privileges
	if not channel:canRead(player.priv) then return end

	-- Don't add to multiplayer channels (those are match-specific)
	if data.channel_name:sub(1, 7) == "#multi_" then return end

	-- Add player to channel
	channel:add(player)

	-- Send join success
	player:enqueue(ServerPackets.channelJoin(channel.name))

	-- Broadcast channel info update to all who can see it
	local count = 0
	for _ in pairs(channel.players) do count = count + 1 end
	local info = ServerPackets.channelInfo(channel.real_name, channel.topic, count)
	for _, p in pairs(channel.players) do
		p:enqueue(info)
	end
end

return ChannelJoin
