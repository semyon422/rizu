--- Packet 98: USER_PRESENCE_REQUEST_ALL
--- Player requests presence data for all online users.
--- Only used when >256 players are visible.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- User presence request all handler data.
---@class bancho.handler.UserPresenceRequestAllData
---@field ingame_time integer

--- Packet 98: USER_PRESENCE_REQUEST_ALL
---@class bancho.handler.UserPresenceRequestAll: bancho.handler.IPacketHandler
---@operator call: bancho.handler.UserPresenceRequestAll
local UserPresenceRequestAll = IPacketHandler + {}

---@return bancho.handler.UserPresenceRequestAllData
function UserPresenceRequestAll:parse(reader, bodyLen)
	return { ingame_time = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.UserPresenceRequestAllData
function UserPresenceRequestAll:handle(server, player, data)
	-- Build presence bundle for all unrestricted players
	for _, target in ipairs(server.players:all()) do
		if target.restricted then goto continue end

		local pkt = ServerPackets.userPresence(
			target.id,
			target.name,
			target.utc_offset,
			0, -- country_code (TODO: geo)
			target:bancho_priv(),
			target.status.mode,
			0, -- longitude (TODO: geo)
			0, -- latitude (TODO: geo)
			target.stats[target.status.mode].rank
		)
		player:enqueue(pkt)

		::continue::
	end
end

return UserPresenceRequestAll
