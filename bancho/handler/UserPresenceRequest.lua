--- Packet 97: USER_PRESENCE_REQUEST
--- Player requests presence data for specific users.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- User presence request handler data.
---@class bancho.handler.UserPresenceRequestData
---@field user_ids integer[]

--- Packet 97: USER_PRESENCE_REQUEST
---@class bancho.handler.UserPresenceRequest: bancho.handler.IPacketHandler
---@operator call: bancho.handler.UserPresenceRequest
local UserPresenceRequest = IPacketHandler + {}

---@return bancho.handler.UserPresenceRequestData
function UserPresenceRequest:parse(reader, bodyLen)
	return { user_ids = reader:readI32List() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.UserPresenceRequestData
function UserPresenceRequest:handle(server, player, data)
	for _, userId in ipairs(data.user_ids) do
		local target = server.players:get(nil, userId)
		if not target then goto continue end

		-- Send bot presence for bot, normal presence for others
		local bot = server:getBot()
		if bot and target.id == bot.id then
			-- TODO: bot presence packet
			goto continue
		end

		local pkt = ServerPackets.userPresence(
			target.id,
			target.name,
			target.utc_offset,
			0, -- country_code (TODO: geo)
			target:bancho_priv(),
			target.status.mode,
			0, -- longitude (TODO: geo)
			0, -- latitude (TODO: geo)
			target.stats[target.status.mode].rank
		)
		player:enqueue(pkt)

		::continue::
	end
end

return UserPresenceRequest
