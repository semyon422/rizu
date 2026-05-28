--- Packet 82: SET_AWAY_MESSAGE
--- Player sets their away message.

local ComplexTypes = require("bancho.protocol.ComplexTypes")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Set away message handler data.
---@class bancho.handler.SetAwayMessageData: bancho.protocol.Message

--- Packet 82: SET_AWAY_MESSAGE
---@class bancho.handler.SetAwayMessage: bancho.handler.IPacketHandler
---@operator call: bancho.handler.SetAwayMessage
local SetAwayMessage = IPacketHandler + {}

---@return bancho.handler.SetAwayMessageData
function SetAwayMessage:parse(reader, bodyLen)
	return ComplexTypes.readMessage(reader)
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.SetAwayMessageData
function SetAwayMessage:handle(server, player, data)
	player.away_msg = data.text
end

return SetAwayMessage
