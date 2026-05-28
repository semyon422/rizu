--- Packet 78: CHANNEL_PART
--- Client leaves a chat channel.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Channel part handler data.
---@class bancho.handler.ChannelPartData
---@field channel_name string

--- Packet 78: CHANNEL_PART
---@class bancho.handler.ChannelPart: bancho.handler.IPacketHandler
---@operator call: bancho.handler.ChannelPart
local ChannelPart = IPacketHandler + {}

---@return bancho.handler.ChannelPartData
function ChannelPart:parse(reader, bodyLen)
	return { channel_name = reader:readString() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.ChannelPartData
function ChannelPart:handle(server, player, data)
	local channel = server.channels:get(data.channel_name)
	if not channel then return end
	if not channel:contains(player) then return end

	-- Remove player from channel
	channel:remove(player)

	-- Broadcast channel info update
	local count = 0
	for _ in pairs(channel.players) do count = count + 1 end
	local info = ServerPackets.channelInfo(channel.real_name, channel.topic, count)
	for _, p in pairs(channel.players) do
		p:enqueue(info)
	end
end

return ChannelPart
