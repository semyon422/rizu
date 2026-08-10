local class = require("class")
local UsersRepo = require("sea.access.repos.UsersRepo")
local LeaderboardsRepo = require("sea.leaderboards.repos.LeaderboardsRepo")
local TeamsRepo = require("sea.teams.repos.TeamsRepo")
local DifftablesRepo = require("sea.difftables.repos.DifftablesRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartfilesRepo = require("sea.chart.repos.ChartfilesRepo")
local ComputeTasksRepo = require("sea.compute.repos.ComputeTasksRepo")
local ComputeJobsRepo = require("sea.compute.repos.ComputeJobsRepo")
local ChartplayEffectsRepo = require("sea.compute.repos.ChartplayEffectsRepo")
local DanClearsRepo = require("sea.dan.repos.DanClearsRepo")
local ActivityRepo = require("sea.activity.repos.ActivityRepo")
local OsuRepo = require("sea.osu.repos.OsuRepo")
local UserConnectionsRepo = require("sea.app.repos.UserConnectionsRepo")
local MultiplayerRepo = require("sea.app.repos.MultiplayerRepo")

---@class sea.Repos
---@field multiplayer_repo sea.MultiplayerRepo
---@operator call: sea.Repos
local Repos = class()

---@param models rdb.Models
---@param shared_memory web.SharedMemory
function Repos:new(models, shared_memory)
	self.users_repo = UsersRepo(models)
	self.leaderboards_repo = LeaderboardsRepo(models)
	self.teams_repo = TeamsRepo(models)
	self.difftables_repo = DifftablesRepo(models)
	self.charts_repo = ChartsRepo(models)
	self.chartfiles_repo = ChartfilesRepo(models)
	self.compute_tasks_repo = ComputeTasksRepo(models)
	self.compute_jobs_repo = ComputeJobsRepo(models)
	self.chartplay_effects_repo = ChartplayEffectsRepo(models)
	self.dan_clears_repo = DanClearsRepo(models)
	self.activity_repo = ActivityRepo(models)
	self.osu_repo = OsuRepo(models)
	self.user_connections_repo = UserConnectionsRepo(shared_memory:get("players"))
	self.multiplayer_repo = MultiplayerRepo(shared_memory:get("mp_rooms"), shared_memory:get("mp_room_users"))
end

return Repos
