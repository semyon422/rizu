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
		local mode = target.status.mode:asVanilla()
		local stats = server.stats_repo and server.stats_repo:getStats(target.id, mode) or {}
		local pkt = ServerPackets.userStats(
			target.id,
			target.status.action,
			target.status.info_text,
			target.status.map_md5,
			target.status.mods,
			mode,
			target.status.map_id,
			stats.rscore or 0,
			stats.acc or 0,
			stats.plays or 0,
			stats.tscore or 0,
			stats.rank or 0,
			stats.pp or 0
		)
		player:enqueue(pkt)

		::continue::
	end
end

return UserStatsRequest
