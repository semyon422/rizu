--- Packet 77: MATCH_CHANGE_TEAM
--- Player toggles their team in head-to-head or team matches.

local ServerPackets = require("bancho.protocol.ServerPackets")
local MatchConstants = require("bancho.constants.MatchConstants")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match change team handler data (empty).
---@class bancho.handler.MatchChangeTeamData

--- Packet 77: MATCH_CHANGE_TEAM
---@class bancho.handler.MatchChangeTeam: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchChangeTeam
local MatchChangeTeam = IPacketHandler + {}

---@return bancho.handler.MatchChangeTeamData
function MatchChangeTeam:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchChangeTeamData
function MatchChangeTeam:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	-- Toggle team
	if slot.team == MatchConstants.MatchTeams.BLUE then
		slot.team = MatchConstants.MatchTeams.RED
	else
		slot.team = MatchConstants.MatchTeams.BLUE
	end

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchChangeTeam
