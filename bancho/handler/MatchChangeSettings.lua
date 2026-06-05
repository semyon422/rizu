--- Packet 41: MATCH_CHANGE_SETTINGS
--- Host changes match settings (map, mode, mods, etc.).

local ServerPackets = require("bancho.protocol.ServerPackets")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match change settings handler data.
---@class bancho.handler.MatchChangeSettingsData: bancho.protocol.MultiplayerMatch

--- Packet 41: MATCH_CHANGE_SETTINGS
---@class bancho.handler.MatchChangeSettings: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchChangeSettings
local MatchChangeSettings = IPacketHandler + {}

---@return bancho.handler.MatchChangeSettingsData
function MatchChangeSettings:parse(reader, bodyLen)
	return ComplexTypes.readMatch(reader)
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchChangeSettingsData
function MatchChangeSettings:handle(server, player, data)
	if not player.match then return end

	-- Only host can change settings
	if player.match.host_id ~= player.id then return end

	-- Validate: host ID must match
	if data.host_id ~= player.id then return end

	local match = player.match

	-- Track freemods change for slot mods reset
	local freemodsChanged = data.freemods ~= match.freemods

	-- Apply settings
	match.name = data.name
	match.freemods = data.freemods
	match.mods = data.mods
	match.mode = data.mode
	match.win_condition = data.win_condition
	match.team_type = data.team_type
	match.map_id = data.map_id
	match.map_md5 = data.map_md5
	match.map_name = data.map_name

	-- If freemods changed, reset all slot mods
	if freemodsChanged then
		for i = 0, 15 do
			if match.slots[i].player ~= nil then
				match.slots[i].mods = 0
			end
		end
	end

	-- Preserve client-provided open/locked layout for empty slots.
	for i = 1, 16 do
		local idx = i - 1
		local slot = match.slots[idx]
		if slot.player == nil and slot.player_id == nil then
			local status = data.slot_statuses[i]
			if status == SlotStatus.OPEN or status == SlotStatus.LOCKED then
				slot.status = status
			end
			slot.team = data.slot_teams[i]
		end
	end

	local match_data = server.match_manager:buildMatchData(match)
	server.chat_manager:notifyMatchUpdate(match, match_data, server.channels, true)
end

return MatchChangeSettings
