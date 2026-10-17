--- Packet 93: TOURNAMENT_MATCH_INFO_REQUEST
--- Tournament map pool info request.
---
--- NOTE: Tournament system not implemented. This handler is a stub.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Tournament match info request handler data (empty).
---@class bancho.handler.TournamentMatchInfoRequestData

--- Packet 93: TOURNAMENT_MATCH_INFO_REQUEST
---@class bancho.handler.TournamentMatchInfoRequest: bancho.handler.IPacketHandler
---@operator call: bancho.handler.TournamentMatchInfoRequest
local TournamentMatchInfoRequest = IPacketHandler + {}

---@return bancho.handler.TournamentMatchInfoRequestData
function TournamentMatchInfoRequest:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.TournamentMatchInfoRequestData
function TournamentMatchInfoRequest:handle(server, player, data)
	-- TODO: tournament system not implemented
end

return TournamentMatchInfoRequest
