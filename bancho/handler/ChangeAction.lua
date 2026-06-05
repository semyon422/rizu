--- Packet 0: CHANGE_ACTION
--- Client updates their status (action, map, mods, mode, etc.).

local Action = require("bancho.constants.Action")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")
local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Change action handler data.
---@class bancho.handler.ChangeActionData
---@field action integer
---@field info_text string
---@field map_md5 string
---@field mods integer
---@field mode integer
---@field map_id integer

--- Packet 0: CHANGE_ACTION
---@class bancho.handler.ChangeAction: bancho.handler.IPacketHandler
---@operator call: bancho.handler.ChangeAction
local ChangeAction = IPacketHandler + {}

---@param reader bancho.protocol.PacketReader
---@param bodyLen integer
---@return bancho.handler.ChangeActionData
function ChangeAction:parse(reader, bodyLen)
	return {
		action = reader:readU8(),
		info_text = reader:readString(),
		map_md5 = reader:readString(),
		mods = reader:readU32(),
		mode = reader:readU8(),
		map_id = reader:readI32(),
	}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.ChangeActionData
function ChangeAction:handle(server, player, data)
	-- Apply relax/autopilot mode adjustments
	local mode = data.mode
	local mods = data.mods

	if bit.band(mods, Mods.RELAX) ~= 0 then
		if mode == 3 then
			mods = bit.band(mods, bit.bnot(Mods.RELAX))
		else
			mode = mode + 4
		end
	elseif bit.band(mods, Mods.AUTOPILOT) ~= 0 then
		if mode >= 1 and mode <= 3 then
			mods = bit.band(mods, bit.bnot(Mods.AUTOPILOT))
		else
			mode = mode + 8
		end
	end

	-- Update player status
	player.status.action = Action.fromValue(data.action)
	player.status.info_text = data.info_text
	player.status.map_md5 = data.map_md5
	player.status.mods = mods
	player.status.mode = GameMode.fromValue(mode)
	player.status.map_id = data.map_id

	-- Broadcast updated stats to all online players
	local mode = player.status.mode:asVanilla()
	local stats = server.stats_repo and server.stats_repo:getStats(player.id, mode) or {}

	server.players:enqueue(
		ServerPackets.userStats(
			player.id,
			player.status.action,
			player.status.info_text,
			player.status.map_md5,
			player.status.mods,
			mode,
			player.status.map_id,
			stats.rscore or 0,
			stats.acc or 0,
			stats.plays or 0,
			stats.tscore or 0,
			stats.rank or 0,
			stats.pp or 0
		)
	)
end

return ChangeAction
