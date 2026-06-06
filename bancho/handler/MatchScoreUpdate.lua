--- Packet 47: MATCH_SCORE_UPDATE
--- Client sends a score frame during an active match.
--- Forwarded to all other players in the match.

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

	local slot_id = match:getSlotId(player)
	if slot_id == nil then return end

	data.score_frame.id = slot_id
	local packet = ServerPackets.matchScoreUpdate(data.score_frame)

	for i = 0, 15 do
		local slot = match.slots[i]
		local target = slot.player
		if not target and slot.player_id then
			target = server.players:get(nil, slot.player_id)
		end
		if target and target.id ~= player.id then
			if server.players._dict then
				server.players._dict:rpush("pq:" .. target.token, packet)
			else
				target:enqueue(packet)
			end
		end
	end
end

return MatchScoreUpdate
