--- Packet 38: MATCH_CHANGE_SLOT
--- Player moves to a different slot in the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match change slot handler data.
---@class bancho.handler.MatchChangeSlotData
---@field slot_id integer

--- Packet 38: MATCH_CHANGE_SLOT
---@class bancho.handler.MatchChangeSlot: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchChangeSlot
local MatchChangeSlot = IPacketHandler + {}

---@return bancho.handler.MatchChangeSlotData
function MatchChangeSlot:parse(reader, bodyLen)
	return { slot_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchChangeSlotData
function MatchChangeSlot:handle(server, player, data)
	if not player.match then return end

	-- Validate slot range
	if data.slot_id < 0 or data.slot_id > 15 then return end

	local match = player.match

	-- Target slot must be open
	if match.slots[data.slot_id].status ~= SlotStatus.OPEN then return end

	-- Get current slot
	local currentSlot = match:getSlot(player)
	if not currentSlot then return end

	-- Copy current slot data to target slot
	match.slots[data.slot_id]:copyFrom(currentSlot)

	-- Reset current slot
	currentSlot:reset()

	-- Update player's match reference
	player.match = match

	-- Broadcast updated match state
	local match_data = server.match_manager:buildMatchData(match)
	if match.chat then
		for _, p in pairs(match.chat.players) do
			p:enqueue(ServerPackets.updateMatch(match_data))
		end
	end
end

return MatchChangeSlot
