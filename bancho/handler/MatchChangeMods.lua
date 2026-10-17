--- Packet 51: MATCH_CHANGE_MODS
--- Player changes their mods in the match.

local bit = require("bit")
local ServerPackets = require("bancho.protocol.ServerPackets")
local Mods = require("bancho.constants.Mods")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match change mods handler data.
---@class bancho.handler.MatchChangeModsData
---@field mods integer

--- Packet 51: MATCH_CHANGE_MODS
---@class bancho.handler.MatchChangeMods: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchChangeMods
local MatchChangeMods = IPacketHandler + {}

---@return bancho.handler.MatchChangeModsData
function MatchChangeMods:parse(reader, bodyLen)
	return { mods = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchChangeModsData
function MatchChangeMods:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	if match.freemods then
		-- Host can set speed-changing mods for the match
		if player.id == match.host_id then
			match.mods = bit.band(data.mods, Mods.SPEED_CHANGING_MODS)
		end
		-- Player sets their own slot mods (non-speed-changing)
		slot.mods = bit.band(data.mods, bit.bnot(Mods.SPEED_CHANGING_MODS))
	else
		-- Only host can change mods in non-freemods matches
		if player.id ~= match.host_id then return end
		match.mods = data.mods
	end

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchChangeMods
