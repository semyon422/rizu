--- Packet 3: REQUEST_STATUS_UPDATE
--- Client requests their own stats to be sent back.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Status update request data (empty).
---@class bancho.handler.StatusUpdateRequestData

--- Packet 3: REQUEST_STATUS_UPDATE
---@class bancho.handler.StatusUpdateRequest: bancho.handler.IPacketHandler
---@operator call: bancho.handler.StatusUpdateRequest
local StatusUpdateRequest = IPacketHandler + {}

---@return bancho.handler.StatusUpdateRequestData
function StatusUpdateRequest:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.StatusUpdateRequestData
function StatusUpdateRequest:handle(server, player, data)
	local mode = player.status.mode:asVanilla()
	local stats = server.stats_repo and server.stats_repo:getStats(player.id, mode) or {}

	player:enqueue(ServerPackets.userStats(
		player.id,
		player.status.action,
		player.status.info_text,
		player.status.map_md5,
		player.status.mods,
		mode,
		player.status.map_id,
		stats.rscore or 0,
		stats.acc or 0,
		stats.plays or 0,
		stats.tscore or 0,
		stats.rank or 0,
		stats.pp or 0
	))
end

return StatusUpdateRequest
