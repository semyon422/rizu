--- Packet 87: MATCH_INVITE
--- Player invites another player to their match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match invite handler data.
---@class bancho.handler.MatchInviteData
---@field user_id integer

--- Packet 87: MATCH_INVITE
---@class bancho.handler.MatchInvite: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchInvite
local MatchInvite = IPacketHandler + {}

---@return bancho.handler.MatchInviteData
function MatchInvite:parse(reader, bodyLen)
	return { user_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchInviteData
function MatchInvite:handle(server, player, data)
	if not player.match then return end

	local target = server.players:get(nil, data.user_id)
	if not target then return end

	-- Don't invite bot
	local bot = server:getBot()
	if bot and target.id == bot.id then
		-- TODO: send bot response
		return
	end

	-- Send invite to target
	local msg = "You have been invited to " .. player.name .. "'s match!"
	local pkt = ServerPackets.matchInvite(player.name, msg, target.name, player.id)
	target:enqueue(pkt)
end

return MatchInvite
