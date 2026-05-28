--- Packet 29: PART_LOBBY
--- Player leaves the multiplayer lobby.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Part lobby handler data (empty).
---@class bancho.handler.PartLobbyData

--- Packet 29: PART_LOBBY
---@class bancho.handler.PartLobby: bancho.handler.IPacketHandler
---@operator call: bancho.handler.PartLobby
local PartLobby = IPacketHandler + {}

---@return bancho.handler.PartLobbyData
function PartLobby:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.PartLobbyData
function PartLobby:handle(server, player, data)
	player.in_lobby = false
end

return PartLobby
