--- Packet 41: MATCH_CHANGE_SETTINGS
--- Host changes match settings (map, mode, mods, etc.).

local ServerPackets = require("bancho.protocol.ServerPackets")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
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

	-- Broadcast updated match state
	local match_data = server.match_manager:buildMatchData(match)
	if match.chat then
		for _, p in pairs(match.chat.players) do
			p:enqueue(ServerPackets.updateMatch(match_data))
		end
	end
end

return MatchChangeSettings
