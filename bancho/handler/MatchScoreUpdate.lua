--- Packet 47: MATCH_SCORE_UPDATE
--- Client sends a score frame during an active match.
--- Forwarded to all other players in the match.

local Binary = require("bancho.protocol.Binary")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match score update handler data.
---@class bancho.handler.MatchScoreUpdateData
---@field score_frame bancho.protocol.ScoreFrame

--- Packet 47: MATCH_SCORE_UPDATE
---@class bancho.handler.MatchScoreUpdate: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchScoreUpdate
local MatchScoreUpdate = IPacketHandler + {}

---@return bancho.handler.MatchScoreUpdateData
function MatchScoreUpdate:parse(reader, bodyLen)
	return { score_frame = ComplexTypes.readScoreFrame(reader) }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchScoreUpdateData
function MatchScoreUpdate:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	if not match.in_progress then return end

	local slot = match:getSlot(player)
	if not slot then return end

	-- Build score update packet
	local packet = ServerPackets.matchScoreUpdate(data.score_frame)

	-- Prepend slot ID (i32) to identify which player sent it
	local full_packet = Binary.writeI32(slot) .. packet

	-- Send to all other players in the match
	for i = 0, 15 do
		local slot = match.slots[i]
		local target = slot.player
		if not target and slot.player_id then
			target = server.players:get(nil, slot.player_id)
		end
		if target and target.id ~= player.id then
			target:enqueue(full_packet)
		end
	end
end

return MatchScoreUpdate
