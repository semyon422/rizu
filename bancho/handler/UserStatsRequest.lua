--- Packet 85: USER_STATS_REQUEST
--- Player requests stats for specific users.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- User stats request handler data.
---@class bancho.handler.UserStatsRequestData
---@field user_ids integer[]

--- Packet 85: USER_STATS_REQUEST
---@class bancho.handler.UserStatsRequest: bancho.handler.IPacketHandler
---@operator call: bancho.handler.UserStatsRequest
local UserStatsRequest = IPacketHandler + {}

---@return bancho.handler.UserStatsRequestData
function UserStatsRequest:parse(reader, bodyLen)
	return { user_ids = reader:readI32List() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.UserStatsRequestData
function UserStatsRequest:handle(server, player, data)
	for _, userId in ipairs(data.user_ids) do
		-- Skip self
		if userId == player.id then goto continue end

		-- Skip restricted players
		local target = server.players:get(nil, userId)
		if not target then goto continue end
		if target.restricted then goto continue end

		-- Send user stats
		local mode = target.status.mode
		local stats = target.stats[mode]
		local pkt = ServerPackets.userStats(
			target.id,
			target.status.action,
			target.status.info_text,
			target.status.map_md5,
			target.status.mods,
			mode,
			target.status.map_id,
			stats.rscore,
			stats.acc,
			stats.plays,
			stats.tscore,
			stats.rank,
			stats.pp
		)
		player:enqueue(pkt)

		::continue::
	end
end

return UserStatsRequest
