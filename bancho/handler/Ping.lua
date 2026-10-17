--- Packet 4: PING
--- Client sends a ping; server responds with nothing (client handles timing).

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Ping handler data (empty).
---@class bancho.handler.PingData

--- Packet 4: PING
---@class bancho.handler.Ping: bancho.handler.IPacketHandler
---@operator call: bancho.handler.Ping
local Ping = IPacketHandler + {}

---@return bancho.handler.PingData
function Ping:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.PingData
function Ping:handle(server, player, data)
	-- No response needed; client handles ping timing.
end

return Ping
