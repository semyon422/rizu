--- Packet 99: TOGGLE_BLOCK_NON_FRIEND_DMS
--- Player toggles blocking of non-friend DMs.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Toggle block non-friend DMs handler data.
---@class bancho.handler.ToggleBlockNonFriendDmsData
---@field value integer

--- Packet 99: TOGGLE_BLOCK_NON_FRIEND_DMS
---@class bancho.handler.ToggleBlockNonFriendDms: bancho.handler.IPacketHandler
---@operator call: bancho.handler.ToggleBlockNonFriendDms
local ToggleBlockNonFriendDms = IPacketHandler + {}

---@return bancho.handler.ToggleBlockNonFriendDmsData
function ToggleBlockNonFriendDms:parse(reader, bodyLen)
	return { value = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.ToggleBlockNonFriendDmsData
function ToggleBlockNonFriendDms:handle(server, player, data)
	-- Persist to database
	if server.user_repo then
		server.user_repo:updateSessionPrefs(player.id, {pm_private = (data.value == 1)})
	end
end

return ToggleBlockNonFriendDms
