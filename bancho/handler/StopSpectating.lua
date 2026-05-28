--- Packet 17: STOP_SPECTATING
--- Client stops spectating.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Stop spectating handler data (empty).
---@class bancho.handler.StopSpectatingData

--- Packet 17: STOP_SPECTATING
---@class bancho.handler.StopSpectating: bancho.handler.IPacketHandler
---@operator call: bancho.handler.StopSpectating
local StopSpectating = IPacketHandler + {}

---@return bancho.handler.StopSpectatingData
function StopSpectating:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.StopSpectatingData
function StopSpectating:handle(server, player, data)
	if not player.spectating then return end

	local host = player.spectating

	-- Remove from host's spectator list
	host:removeSpectator(player)

	-- Notify host
	host:enqueue(ServerPackets.spectatorLeft(player.id))

	-- Notify fellow spectators
	local left = ServerPackets.fellowSpectatorLeft(player.id)
	for _, spec in ipairs(host.spectators) do
		spec:enqueue(left)
	end

	player.spectating = nil
end

return StopSpectating
