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
local BanchoDatabase = require("bancho.db.BanchoDatabase")

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
---@field addScore fun(self: bancho.server.IScoreRepo, score: table): integer

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
---@field saveReplay fun(self: bancho.server.IReplayRepo, score_id: integer, data: string): boolean
---@field getReplay fun(self: bancho.server.IReplayRepo, score_id: integer): string?

--- Server configuration.
---@class bancho.server.BanchoConfig
---@field domain string Server domain (e.g. "rizu.su")
---@field osu_domains string[] Domains that serve osu! endpoints
---@field bancho_domains string[] Domains that serve bancho protocol
---@field bot_name string Bot player name
---@field bot_id integer Bot player ID
---@field max_matches integer Maximum concurrent matches
---@field allow_registration boolean Allow in-game registration
---@field seasonal_backgrounds table[] Seasonal background configuration
---@field command_prefix string Command prefix character
---@field menu_icon_url string Main menu icon URL
---@field menu_onclick_url string Main menu icon click URL

---@class bancho.server.BanchoServer
---@operator call: bancho.server.BanchoServer
---@field db? bancho.BanchoDatabase
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
local BanchoServer = class()

---@param config bancho.server.BanchoConfig
function BanchoServer:new(config)
	self.config = config or {}
	self.config.domain = self.config.domain or "rizu.su"
	self.config.bot_name = self.config.bot_name or "bot"
	self.config.bot_id = self.config.bot_id or 1
	self.config.max_matches = self.config.max_matches or 64
	self.config.allow_registration = self.config.allow_registration ~= false
	self.config.seasonal_backgrounds = self.config.seasonal_backgrounds or {}
	self.config.command_prefix = self.config.command_prefix or "!"
	self.config.menu_icon_url = self.config.menu_icon_url or ""
	self.config.menu_onclick_url = self.config.menu_onclick_url or ""

	self.players = PlayerCollection()
	self.matches = MatchCollection(self.config.max_matches)
	self.channels = ChannelCollection()
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
	return self
end

--- Initialize default channels.
function BanchoServer:initializeChannels()
	self.channels:add(Channel("#lobby", "Multiplayer lobby", 0, 0, false, false))
	self.channels:add(Channel("#beginners", "For osu! beginners", 0, 0, true, false))
	self.channels:add(Channel("#general", "General discussion", 0, 0, true, false))
	self.channels:add(Channel("#halp", "Technical support", 0, 0, true, false))
	self.channels:add(Channel("#shout", "Shout channel", 0, 0, false, false))
	self.channels:add(Channel("#announce", "Announcements", 1, 0, true, false))
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

--- Set up SQLite database and wire all repos automatically.
--- This is a convenience method that creates a BanchoDatabase, opens it,
--- and wires all repos from `bancho.db.repos`.
---@param path string? Database file path (default: "bancho.db")
function BanchoServer:setupDatabase(path)
	local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
	local Repos = require("bancho.db.repos")

	self.db = BanchoDatabase(LjsqliteDatabase())
	if path then
		self.db.path = path
	end
	self.db:open()

	local repos = Repos(self.db.models)
	self:setRepos(
		repos.user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		repos.friends_repo,
		repos.favourites_repo,
		repos.stats_repo,
		repos.replay_repo
	)
end

--- Close the database connection.
function BanchoServer:closeDatabase()
	if self.db then
		self.db:close()
		self.db = nil
	end
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
