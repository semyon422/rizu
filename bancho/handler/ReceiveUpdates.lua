--- Packet 79: RECEIVE_UPDATES
--- Player toggles presence update reception.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Receive updates handler data.
---@class bancho.handler.ReceiveUpdatesData
---@field value integer

--- Packet 79: RECEIVE_UPDATES
---@class bancho.handler.ReceiveUpdates: bancho.handler.IPacketHandler
---@operator call: bancho.handler.ReceiveUpdates
local ReceiveUpdates = IPacketHandler + {}

---@return bancho.handler.ReceiveUpdatesData
function ReceiveUpdates:parse(reader, bodyLen)
	return { value = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.ReceiveUpdatesData
function ReceiveUpdates:handle(server, player, data)
	-- Valid values: 0 = all, 1 = mods only, 2 = friends only
	if data.value < 0 or data.value > 2 then return end

	player.pres_filter = data.value
end

return ReceiveUpdates
