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
	router:register(ClientPackets.SEND_PRIVATE_MESSAGE, require("bancho.handler.SendPrivateMessage")(), "SendPrivateMessage")

	-- Spectating
	router:register(ClientPackets.START_SPECTATING, require("bancho.handler.StartSpectating")(), "StartSpectating")
	router:register(ClientPackets.STOP_SPECTATING, require("bancho.handler.StopSpectating")(), "StopSpectating")
	router:register(ClientPackets.SPECTATE_FRAMES, require("bancho.handler.SpectateFrames")(), "SpectateFrames")
	router:register(ClientPackets.CANT_SPECTATE, require("bancho.handler.CantSpectate")(), "CantSpectate")

	-- Lobby
	router:register(ClientPackets.PART_LOBBY, require("bancho.handler.PartLobby")(), "PartLobby")
	router:register(ClientPackets.JOIN_LOBBY, require("bancho.handler.JoinLobby")(), "JoinLobby")

	-- Multiplayer
	router:register(ClientPackets.CREATE_MATCH, require("bancho.handler.CreateMatch")(), "CreateMatch")
	router:register(ClientPackets.JOIN_MATCH, require("bancho.handler.JoinMatch")(), "JoinMatch")
	router:register(ClientPackets.PART_MATCH, require("bancho.handler.PartMatch")(), "PartMatch")
	router:register(ClientPackets.MATCH_CHANGE_SLOT, require("bancho.handler.MatchChangeSlot")(), "MatchChangeSlot")
	router:register(ClientPackets.MATCH_READY, require("bancho.handler.MatchReady")(), "MatchReady")
	router:register(ClientPackets.MATCH_LOCK, require("bancho.handler.MatchLock")(), "MatchLock")
	router:register(ClientPackets.MATCH_CHANGE_SETTINGS, require("bancho.handler.MatchChangeSettings")(), "MatchChangeSettings")
	router:register(ClientPackets.MATCH_START, require("bancho.handler.MatchStart")(), "MatchStart")
	router:register(ClientPackets.MATCH_SCORE_UPDATE, require("bancho.handler.MatchScoreUpdate")(), "MatchScoreUpdate")
	router:register(ClientPackets.MATCH_COMPLETE, require("bancho.handler.MatchComplete")(), "MatchComplete")
	router:register(ClientPackets.MATCH_CHANGE_MODS, require("bancho.handler.MatchChangeMods")(), "MatchChangeMods")
	router:register(ClientPackets.MATCH_LOAD_COMPLETE, require("bancho.handler.MatchLoadComplete")(), "MatchLoadComplete")
	router:register(ClientPackets.MATCH_NO_BEATMAP, require("bancho.handler.MatchNoBeatmap")(), "MatchNoBeatmap")
	router:register(ClientPackets.MATCH_NOT_READY, require("bancho.handler.MatchNotReady")(), "MatchNotReady")
	router:register(ClientPackets.MATCH_FAILED, require("bancho.handler.MatchFailed")(), "MatchFailed")
	router:register(ClientPackets.MATCH_HAS_BEATMAP, require("bancho.handler.MatchHasBeatmap")(), "MatchHasBeatmap")
	router:register(ClientPackets.MATCH_SKIP_REQUEST, require("bancho.handler.MatchSkipRequest")(), "MatchSkipRequest")
	router:register(ClientPackets.MATCH_TRANSFER_HOST, require("bancho.handler.MatchTransferHost")(), "MatchTransferHost")
	router:register(ClientPackets.MATCH_CHANGE_TEAM, require("bancho.handler.MatchChangeTeam")(), "MatchChangeTeam")
	router:register(ClientPackets.MATCH_INVITE, require("bancho.handler.MatchInvite")(), "MatchInvite")
	router:register(ClientPackets.MATCH_CHANGE_PASSWORD, require("bancho.handler.MatchChangePassword")(), "MatchChangePassword")

	-- Channels
	router:register(ClientPackets.CHANNEL_JOIN, require("bancho.handler.ChannelJoin")(), "ChannelJoin", true)
	router:register(ClientPackets.CHANNEL_PART, require("bancho.handler.ChannelPart")(), "ChannelPart", true)

	-- Friends
	router:register(ClientPackets.FRIEND_ADD, require("bancho.handler.FriendAdd")(), "FriendAdd")
	router:register(ClientPackets.FRIEND_REMOVE, require("bancho.handler.FriendRemove")(), "FriendRemove")

	-- User status
	router:register(ClientPackets.RECEIVE_UPDATES, require("bancho.handler.ReceiveUpdates")(), "ReceiveUpdates", true)
	router:register(ClientPackets.SET_AWAY_MESSAGE, require("bancho.handler.SetAwayMessage")(), "SetAwayMessage")
	router:register(ClientPackets.USER_STATS_REQUEST, require("bancho.handler.UserStatsRequest")(), "UserStatsRequest", true)
	router:register(ClientPackets.USER_PRESENCE_REQUEST, require("bancho.handler.UserPresenceRequest")(), "UserPresenceRequest")
	router:register(ClientPackets.USER_PRESENCE_REQUEST_ALL, require("bancho.handler.UserPresenceRequestAll")(), "UserPresenceRequestAll")
	router:register(ClientPackets.TOGGLE_BLOCK_NON_FRIEND_DMS, require("bancho.handler.ToggleBlockNonFriendDms")(), "ToggleBlockNonFriendDms")

	-- Tournament (stubs)
	router:register(ClientPackets.TOURNAMENT_MATCH_INFO_REQUEST, require("bancho.handler.TournamentMatchInfoRequest")(), "TournamentMatchInfoRequest")
	router:register(ClientPackets.TOURNAMENT_JOIN_MATCH_CHANNEL, require("bancho.handler.TournamentJoinMatchChannel")(), "TournamentJoinMatchChannel")
	router:register(ClientPackets.TOURNAMENT_LEAVE_MATCH_CHANNEL, require("bancho.handler.TournamentLeaveMatchChannel")(), "TournamentLeaveMatchChannel")
end
