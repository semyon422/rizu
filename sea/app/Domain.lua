local class = require("class")

local Users = require("sea.access.Users")
local UserRoles = require("sea.access.UserRoles")
local UserBadges = require("sea.access.UserBadges")
local IEmailSender = require("sea.access.IEmailSender")
local BcryptPasswordHasher = require("sea.access.BcryptPasswordHasher")

local Leaderboards = require("sea.leaderboards.Leaderboards")

local Teams = require("sea.teams.Teams")
local Dans = require("sea.dan.Dans")

local Difftables = require("sea.difftables.Difftables")

local Chartplays = require("sea.chart.Chartplays")
local ChartplaySubmission = require("sea.chart.ChartplaySubmission")
local FolderStorage = require("sea.chart.storage.FolderStorage")

local ComputeDataProvider = require("sea.compute.ComputeDataProvider")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local ComputeTasks = require("sea.compute.ComputeTasks")
local ChartsComputer = require("sea.compute.ChartsComputer")

local UserActivityGraph = require("sea.activity.UserActivityGraph")

local OsuApi = require("sea.osu.api.OsuApi")
local OsuBeatmaps = require("sea.osu.OsuBeatmaps")
local ExternalRanked = require("sea.difftables.ExternalRanked")
local UserConnections = require("sea.app.UserConnections")
local Multiplayer = require("sea.app.Multiplayer")

---@class sea.Domain
---@field multiplayer sea.Multiplayer
---@operator call: sea.Domain
local Domain = class()

---@param repos sea.Repos
---@param app_config sea.AppConfig
function Domain:new(repos, app_config)
	self.repos = repos
	self.users_repo = repos.users_repo
	self.charts_repo = repos.charts_repo

	self.charts_storage = FolderStorage("storages/charts")
	self.replays_storage = FolderStorage("storages/replays")
	self.compute_data_provider = ComputeDataProvider(repos.chartfiles_repo, self.charts_storage, self.replays_storage)
	self.compute_data_loader = ComputeDataLoader(self.compute_data_provider)

	self.users = Users(repos.users_repo, BcryptPasswordHasher(), IEmailSender())
	self.user_roles = UserRoles(repos.users_repo)
	self.user_badges = UserBadges(repos.users_repo)
	self.leaderboards = Leaderboards(repos.leaderboards_repo)
	self.teams = Teams(repos.teams_repo)
	self.difftables = Difftables(repos.difftables_repo)
	self.chartplays = Chartplays(
		repos.charts_repo,
		repos.chartfiles_repo,
		self.compute_data_loader,
		self.charts_storage,
		self.replays_storage
	)
	self.dans = Dans(repos.charts_repo, repos.dan_clears_repo)
	self.user_activity_graph = UserActivityGraph(repos.activity_repo)

	self.osu_api = OsuApi(app_config.osu_api, "client_credentials")
	self.osu_beatmaps = OsuBeatmaps(self.osu_api, repos.osu_repo)
	self.external_ranked = ExternalRanked(self.osu_beatmaps, repos.difftables_repo)
	self.chartplay_submission = ChartplaySubmission(
		self.chartplays,
		self.leaderboards,
		self.users,
		self.dans,
		self.user_activity_graph,
		self.external_ranked
	)

	self.charts_computer = ChartsComputer(self.compute_data_loader, repos.charts_repo)
	self.compute_tasks = ComputeTasks(repos.compute_tasks_repo)

	self.user_connections = UserConnections(repos.user_connections_repo, repos.users_repo)
	self.multiplayer = Multiplayer(repos.multiplayer_repo, self.user_connections)
end

---@param f function
---@param ... any
---@return any ...
function Domain:transaction(f, ...)
	local orm = self.repos.users_repo.models._orm
	orm:begin()
	local results = {xpcall(f, debug.traceback, ...)}
	if results[1] then
		orm:commit()
		return select(2, unpack(results))
	else
		orm.db:exec("ROLLBACK")
		error(results[2])
	end
end

---@param peer sea.Peer
function Domain:onConnect(peer)
	self.user_connections:onConnect(peer.peer_id, peer.user.id)
	self.multiplayer:connected(peer)
end

---@param peer sea.Peer
function Domain:onDisconnect(peer)
	self.multiplayer:disconnected(peer)
	self.user_connections:onDisconnect(peer.peer_id, peer.user.id)
	self.multiplayer:pushUsers()
end

---@param peer sea.Peer
---@param old_user sea.User
function Domain:onAuth(peer, old_user)
	if old_user and not old_user:isAnon() and old_user.id ~= peer.user.id then
		self.multiplayer:leaveRoom(peer, old_user)
	end

	-- Subscribe to user-targeted broadcasts
	peer:subscribe("icc.broadcast.user." .. peer.user.id)

	self.multiplayer:connected(peer)
end

---@param msg string
---@param caller_peer sea.Peer
function Domain:printAll(msg, caller_peer)
	self.user_connections:broadcastAll():print(msg)
end

---@param caller_peer sea.Peer
---@return number[]
function Domain:getRandomNumbersFromAllClients(caller_peer)
	local peers = self.user_connections:getPeers(caller_peer)
	local numbers = {}
	for _, peer in ipairs(peers) do
		local ok, num = pcall(peer.remote.getRandomNumber, peer.remote)
		if ok then
			table.insert(numbers, num)
		else
			print("Error getting random number from peer:", num)
		end
	end
	return numbers
end

return Domain
