--- Packet 16: START_SPECTATING
--- Client starts spectating another player.

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

--- Start spectating handler data.
---@class bancho.handler.StartSpectatingData
---@field target_id integer

--- Packet 16: START_SPECTATING
---@class bancho.handler.StartSpectating: bancho.handler.IPacketHandler
---@operator call: bancho.handler.StartSpectating
local StartSpectating = IPacketHandler + {}

---@return bancho.handler.StartSpectatingData
function StartSpectating:parse(reader, bodyLen)
	return { target_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.StartSpectatingData
function StartSpectating:handle(server, player, data)
	local target = server.players:get(nil, data.target_id)
	if not target then return end

	-- If already spectating someone, switch
	if player.spectating then
		if player.spectating.id == target.id then
			enqueue_player(server.players, target, ServerPackets.spectatorJoined(player.id))
			local joined = ServerPackets.fellowSpectatorJoined(player.id)
			for _, spec in ipairs(get_spectators(server, target, player.id)) do
				enqueue_player(server.players, spec, joined)
			end
			return
		end

		local old_target = player.spectating
		local left = ServerPackets.spectatorLeft(player.id)
		enqueue_player(server.players, old_target, left)
		for _, spec in ipairs(get_spectators(server, old_target, player.id)) do
			enqueue_player(server.players, spec, ServerPackets.fellowSpectatorLeft(player.id))
		end
	end

	-- Join new spectate session
	player.spectating = target
	player.spectating_id = target.id

	enqueue_player(server.players, target, ServerPackets.spectatorJoined(player.id))

	local joined = ServerPackets.fellowSpectatorJoined(player.id)
	for _, spec in ipairs(get_spectators(server, target, player.id)) do
		enqueue_player(server.players, spec, joined)
	end
end

return StartSpectating
