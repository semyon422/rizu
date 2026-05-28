--- Packet 16: START_SPECTATING
--- Client starts spectating another player.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

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
			-- Already spectating this player — they got the map
			-- Re-notify host and fellow spectators
			target:enqueue(ServerPackets.spectatorJoined(player.id))
			local joined = ServerPackets.fellowSpectatorJoined(player.id)
			for _, spec in ipairs(target.spectators) do
				if spec.id ~= player.id then
					spec:enqueue(joined)
				end
			end
			return
		end
		-- Leave old spectate session
		player.spectating:removeSpectator(player)
		local left = ServerPackets.spectatorLeft(player.id)
		player.spectating:enqueue(left)
		for _, spec in ipairs(player.spectating.spectators) do
			spec:enqueue(ServerPackets.fellowSpectatorLeft(player.id))
		end
	end

	-- Join new spectate session
	player.spectating = target
	table.insert(target.spectators, player)

	-- Notify the host
	target:enqueue(ServerPackets.spectatorJoined(player.id))

	-- Notify fellow spectators
	local joined = ServerPackets.fellowSpectatorJoined(player.id)
	for _, spec in ipairs(target.spectators) do
		if spec.id ~= player.id then
			spec:enqueue(joined)
		end
	end
end

return StartSpectating
