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
	local mode = player.status.mode
	local stats = player.stats[mode] or player.stats[0]

	player:enqueue(ServerPackets.userStats(
		player.id,
		player.status.action,
		player.status.info_text,
		player.status.map_md5,
		player.status.mods,
		mode,
		player.status.map_id,
		stats.rscore,
		stats.acc,
		stats.plays,
		stats.tscore,
		stats.rank,
		stats.pp
	))
end

return StatusUpdateRequest
