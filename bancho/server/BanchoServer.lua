--- Central Bancho server state.
---
--- Holds shared collections (players, matches, channels) and repository
--- references. All HTTP resources and packet handlers receive this instance
--- to access server-wide state.

local PlayerCollection = require("bancho.model.PlayerCollection")
local MatchCollection = require("bancho.model.MatchCollection")
local ChannelCollection = require("bancho.model.ChannelCollection")
local Channel = require("bancho.model.Channel")
local LoginHandler = require("bancho.auth.LoginHandler")
local MatchManager = require("bancho.multiplayer.MatchManager")
local ChatManager = require("bancho.chat.ChatManager")
local ScoreSubmitter = require("bancho.score.Submitter")
local PacketRouter = require("bancho.handler.PacketRouter")
local CommandDispatcher = require("bancho.command.CommandDispatcher")
local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
local BanchoConfig = require("bancho.config.BanchoConfig")

local class = require("class")

--- Repository interface for user data.
---@class bancho.server.IUserRepo
---@operator call: bancho.server.IUserRepo
---@field findUser fun(self: bancho.server.IUserRepo, id: integer): table?
---@field findUserByName fun(self: bancho.server.IUserRepo, name: string): table?
---@field findUserByNameAndPassword fun(self: bancho.server.IUserRepo, name: string, password_md5: string): table?
---@field createUser fun(self: bancho.server.IUserRepo, name: string, email: string, pw_bcrypt: string, country: string): table?
---@field partialUpdate fun(self: bancho.server.IUserRepo, id: integer, fields: table): boolean?
---@field findByEmail fun(self: bancho.server.IUserRepo, email: string): table?

--- Repository interface for scores.
---@class bancho.server.IScoreRepo
---@operator call: bancho.server.IScoreRepo
---@field findScores fun(self: bancho.server.IScoreRepo, map_md5: string, mode: integer): table[]
---@field findBestScore fun(self: bancho.server.IScoreRepo, map_md5: string, user_id: integer, mode: integer): table?
---@field findScore fun(self: bancho.server.IScoreRepo, id: integer): table?
---@field submitScore fun(self: bancho.server.IScoreRepo, score: table, beatmap: table, replay_data: string): integer?, string?

--- Repository interface for beatmaps.
---@class bancho.server.IBeatmapRepo
---@operator call: bancho.server.IBeatmapRepo
---@field findBeatmap fun(self: bancho.server.IBeatmapRepo, md5: string): table?
---@field findBeatmapById fun(self: bancho.server.IBeatmapRepo, id: integer): table?

--- Repository interface for friendships.
---@class bancho.server.IFriendsRepo
---@operator call: bancho.server.IFriendsRepo
---@field getFriends fun(self: bancho.server.IFriendsRepo, user_id: integer): integer[]
---@field addFriend fun(self: bancho.server.IFriendsRepo, user_id: integer, friend_id: integer): boolean
---@field removeFriend fun(self: bancho.server.IFriendsRepo, user_id: integer, friend_id: integer): boolean

--- Repository interface for favourites.
---@class bancho.server.IFavouritesRepo
---@operator call: bancho.server.IFavouritesRepo
---@field getFavourites fun(self: bancho.server.IFavouritesRepo, user_id: integer): integer[]
---@field addFavourite fun(self: bancho.server.IFavouritesRepo, user_id: integer, set_id: integer): boolean
---@field removeFavourite fun(self: bancho.server.IFavouritesRepo, user_id: integer, set_id: integer): boolean

--- Repository interface for stats.
---@class bancho.server.IStatsRepo
---@operator call: bancho.server.IStatsRepo
---@field getStats fun(self: bancho.server.IStatsRepo, user_id: integer, mode: integer): table?
---@field updateStats fun(self: bancho.server.IStatsRepo, user_id: integer, mode: integer, fields: table): boolean
---@field createAllModes fun(self: bancho.server.IStatsRepo, user_id: integer): boolean

--- Repository interface for replays.
---@class bancho.server.IReplayRepo
---@operator call: bancho.server.IReplayRepo
---@field getReplay fun(self: bancho.server.IReplayRepo, score_id: integer): string?

--- Server configuration.
--- Loaded from `server-state/bancho_config.lua` via `bancho.config.BanchoConfig`.
--- See `bancho/config.example.lua` for all available options.
---@alias bancho.config bancho.config.BanchoConfig

---@class bancho.server.BanchoServer
---@operator call: bancho.server.BanchoServer
---@field players bancho.model.PlayerCollection
---@field matches bancho.model.MatchCollection
---@field channels bancho.model.ChannelCollection
---@field login_handler bancho.auth.LoginHandler
---@field match_manager bancho.multiplayer.MatchManager
---@field chat_manager bancho.chat.ChatManager
---@field score_submitter bancho.score.Submitter
---@field router bancho.handler.PacketRouter
---@field commands bancho.command.CommandDispatcher
---@field config bancho.server.BanchoConfig
---@field user_repo? bancho.server.IUserRepo
---@field score_repo? bancho.server.IScoreRepo
---@field beatmap_repo? bancho.server.IBeatmapRepo
---@field friends_repo? bancho.server.IFriendsRepo
---@field favourites_repo? bancho.server.IFavouritesRepo
---@field stats_repo? bancho.server.IStatsRepo
---@field replay_repo? bancho.server.IReplayRepo
---@field beatmap_loader? bancho.beatmap.BeatmapLoader
local BanchoServer = class()

---@param shared_memory? web.SharedMemory Shared memory for cross-worker persistence
---@param overrides? table? Runtime overrides merged on top of server-state/bancho_config.lua
function BanchoServer:new(shared_memory, overrides)
	-- Handle positional argument ambiguity: if first arg is a table without
	-- the `get` method of SharedMemory, treat it as overrides.
	if shared_memory and type(shared_memory.get) ~= "function" then
		overrides = shared_memory
		shared_memory = nil
	end

	-- Load production config, which returns a BanchoConfig instance.
	local file_config = require("server-state.bancho_config")

	-- Merge runtime overrides on top of file config
	if overrides then
		self.config = BanchoConfig:merge(file_config, overrides)
	else
		self.config = file_config
	end

	-- Create collections with shared dict backends (or in-memory for tests)
	local player_dict = shared_memory and shared_memory:get("bancho_players")
	local match_dict = shared_memory and shared_memory:get("bancho_matches")
	local channel_dict = shared_memory and shared_memory:get("bancho_channels")

	self.players = PlayerCollection(player_dict)
	self.matches = MatchCollection(match_dict, self.config.max_matches)
	self.channels = ChannelCollection(channel_dict)

	-- Wire cross-reference resolution
	self.players:setMatches(self.matches)
	self.matches:setPlayers(self.players)
	self.channels:setPlayers(self.players)

	self.login_handler = LoginHandler()
	self.match_manager = MatchManager(self.matches)
	self.chat_manager = ChatManager(self.channels)
	self.score_submitter = ScoreSubmitter(self)

	-- Packet router
	self.router = PacketRouter()
	self.router:setServer(self)

	-- Wire match_manager to use server's match collection
	self.match_manager.matches = self.matches

	-- Wire chat_manager to use server's channel collection
	self.chat_manager.channels = self.channels

	-- Command dispatcher
	self.commands = CommandDispatcher(self.config.command_prefix)

	-- Register all handlers and commands
	local registerHandlers = require("bancho.handler")
	registerHandlers(self.router)

	local registerCommands = require("bancho.command")
	registerCommands(self.commands)

	-- Initialize default channels
	self:initializeChannels()

	-- Beatmap loader (parses .osu files, caches in DB)
	local LinuxFilesystem = require("fs.LinuxFilesystem")
	self.beatmap_loader = BeatmapLoader(LinuxFilesystem(), self.config.osu_api_key)
end

--- Initialize default channels.
--- Only creates channels that don't already exist (to avoid overwriting
--- channels that were created by other workers/requests).
function BanchoServer:initializeChannels()
	local default_channels = {
		{"#lobby", "Multiplayer lobby", 0, 0, false, false},
		{"#beginners", "For osu! beginners", 0, 0, true, false},
		{"#general", "General discussion", 0, 0, true, false},
		{"#halp", "Technical support", 0, 0, true, false},
		{"#shout", "Shout channel", 0, 0, false, false},
		{"#announce", "Announcements", 1, 0, true, false},
	}

	for _, ch_data in ipairs(default_channels) do
		if not self.channels:get(ch_data[1]) then
			self.channels:add(Channel(unpack(ch_data)))
		end
	end
end

--- Set repository backends.
---@param user_repo bancho.server.IUserRepo
---@param score_repo bancho.server.IScoreRepo
---@param beatmap_repo bancho.server.IBeatmapRepo
---@param friends_repo? bancho.server.IFriendsRepo
---@param favourites_repo? bancho.server.IFavouritesRepo
---@param stats_repo? bancho.server.IStatsRepo
---@param replay_repo? bancho.server.IReplayRepo
function BanchoServer:setRepos(user_repo, score_repo, beatmap_repo, friends_repo, favourites_repo, stats_repo, replay_repo)
	self.user_repo = user_repo
	self.score_repo = score_repo
	self.beatmap_repo = beatmap_repo
	self.friends_repo = friends_repo
	self.favourites_repo = favourites_repo
	self.stats_repo = stats_repo
	self.replay_repo = replay_repo
end

--- Get or create the bot player.
---@return bancho.model.Player?
function BanchoServer:getBot()
	return self.players:get(nil, self.config.bot_id)
end

--- Process incoming binary data for a player, dispatching packets.
---@param player bancho.model.Player
---@param data string raw binary data
function BanchoServer:processPackets(player, data)
	self.router:dispatch(player, data)
end

return BanchoServer
