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

		local mode = target.status.mode:asVanilla()
		local stats = server.stats_repo and server.stats_repo:getStats(target.id, mode) or {}
		local pkt = ServerPackets.userPresence(
			target.id,
			target.name,
			0, -- utc_offset (TODO: load from DB)
			0, -- country_code (TODO: geo)
			target:bancho_priv(),
			mode,
			0, -- longitude (TODO: geo)
			0, -- latitude (TODO: geo)
			stats.rank or 0
		)
		player:enqueue(pkt)

		::continue::
	end
end

return UserPresenceRequestAll
