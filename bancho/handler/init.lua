--- Packet handler registry.
---
--- Imports all handlers and registers them with the router.
--- Call `require("bancho.handler")(router)` to populate the router.

local ClientPackets = require("bancho.protocol.ClientPackets")

--- Register all packet handlers with the given router.
---@param router bancho.handler.PacketRouter
return function(router)
	-- Restricted packets (available to all players including restricted)
	router:register(ClientPackets.PING, require("bancho.handler.Ping")(), "Ping", true)
	router:register(ClientPackets.CHANGE_ACTION, require("bancho.handler.ChangeAction")(), "ChangeAction", true)
	router:register(ClientPackets.LOGOUT, require("bancho.handler.Logout")(), "Logout", true)
	router:register(ClientPackets.REQUEST_STATUS_UPDATE, require("bancho.handler.StatusUpdateRequest")(), "StatusUpdateRequest", true)

	-- Chat
	router:register(ClientPackets.SEND_PUBLIC_MESSAGE, require("bancho.handler.SendPublicMessage")(), "SendPublicMessage")

	-- Spectating
	router:register(ClientPackets.START_SPECTATING, require("bancho.handler.StartSpectating")(), "StartSpectating")
	router:register(ClientPackets.STOP_SPECTATING, require("bancho.handler.StopSpectating")(), "StopSpectating")
	router:register(ClientPackets.SPECTATE_FRAMES, require("bancho.handler.SpectateFrames")(), "SpectateFrames")

	-- Multiplayer
	router:register(ClientPackets.CREATE_MATCH, require("bancho.handler.CreateMatch")(), "CreateMatch")
	router:register(ClientPackets.JOIN_MATCH, require("bancho.handler.JoinMatch")(), "JoinMatch")
	router:register(ClientPackets.PART_MATCH, require("bancho.handler.PartMatch")(), "PartMatch")
	router:register(ClientPackets.MATCH_READY, require("bancho.handler.MatchReady")(), "MatchReady")
	router:register(ClientPackets.MATCH_START, require("bancho.handler.MatchStart")(), "MatchStart")
	router:register(ClientPackets.MATCH_SCORE_UPDATE, require("bancho.handler.MatchScoreUpdate")(), "MatchScoreUpdate")
	router:register(ClientPackets.MATCH_COMPLETE, require("bancho.handler.MatchComplete")(), "MatchComplete")

	-- Channels
	router:register(ClientPackets.CHANNEL_JOIN, require("bancho.handler.ChannelJoin")(), "ChannelJoin")
	router:register(ClientPackets.CHANNEL_PART, require("bancho.handler.ChannelPart")(), "ChannelPart")
end
