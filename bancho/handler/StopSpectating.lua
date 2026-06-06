--- Packet 17: STOP_SPECTATING
--- Client stops spectating.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

local function enqueue_player(players, player, packet)
	if players and players._dict then
		players._dict:rpush("pq:" .. player.token, packet)
	else
		player:enqueue(packet)
	end
end

local function get_spectators(server, target, exclude_id)
	local result = {}
	for _, candidate in ipairs(server.players:all()) do
		local spectating_id = candidate.spectating and candidate.spectating.id or candidate.spectating_id
		if spectating_id == target.id then
			if not exclude_id or candidate.id ~= exclude_id then
				result[#result + 1] = candidate
			end
		end
	end
	return result
end

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

	local left = ServerPackets.fellowSpectatorLeft(player.id)
	enqueue_player(server.players, host, ServerPackets.spectatorLeft(player.id))

	player.spectating = nil
	player.spectating_id = nil
	for _, spec in ipairs(get_spectators(server, host, player.id)) do
		enqueue_player(server.players, spec, left)
	end
end

return StopSpectating
