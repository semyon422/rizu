--- Packet 18: SPECTATE_FRAMES
--- Client sends replay frames while being spectated.
--- Forwarded as raw bytes to all spectators for efficiency.

local Binary = require("bancho.protocol.Binary")
local IPacketHandler = require("bancho.handler.IPacketHandler")

local function enqueue_player(players, player, packet)
	if players and players._dict then
		players._dict:rpush("pq:" .. player.token, packet)
	else
		player:enqueue(packet)
	end
end

--- Spectate frames handler data.
---@class bancho.handler.SpectateFramesData
---@field raw_data string

--- Packet 18: SPECTATE_FRAMES
---@class bancho.handler.SpectateFrames: bancho.handler.IPacketHandler
---@operator call: bancho.handler.SpectateFrames
local SpectateFrames = IPacketHandler + {}

---@return bancho.handler.SpectateFramesData
function SpectateFrames:parse(reader, bodyLen)
	-- Forward raw body bytes directly — no parsing needed.
	return { raw_data = reader:readBytes(bodyLen) }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.SpectateFramesData
function SpectateFrames:handle(server, player, data)
	-- Build spectate frames packet (ID 15) with raw data
	local packet = Binary.writeHeader(15, #data.raw_data) .. data.raw_data

	for _, spectator in ipairs(server.players:all()) do
		local spectating_id = spectator.spectating and spectator.spectating.id or spectator.spectating_id
		if spectating_id == player.id then
			enqueue_player(server.players, spectator, packet)
		end
	end
end

return SpectateFrames
