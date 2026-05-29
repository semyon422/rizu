--- Repository factory for the bancho module.
---
--- Creates all repository instances from a shared `rdb.Models` instance.

local class = require("class")
local UserRepo = require("bancho.db.repos.UserRepo")
local ScoreRepo = require("bancho.db.repos.ScoreRepo")
local BeatmapRepo = require("bancho.db.repos.BeatmapRepo")
local FriendsRepo = require("bancho.db.repos.FriendsRepo")
local FavouritesRepo = require("bancho.db.repos.FavouritesRepo")
local StatsRepo = require("bancho.db.repos.StatsRepo")
local ReplayRepo = require("bancho.db.repos.ReplayRepo")

---@class bancho.Repos
---@operator call: bancho.Repos
---@field user_repo bancho.UserRepo
---@field score_repo bancho.ScoreRepo
---@field beatmap_repo bancho.BeatmapRepo
---@field friends_repo bancho.FriendsRepo
---@field favourites_repo bancho.FavouritesRepo
---@field stats_repo bancho.StatsRepo
---@field replay_repo bancho.ReplayRepo
local Repos = class()

---@param models rdb.Models
function Repos:new(models)
	self.user_repo = UserRepo(models)
	self.score_repo = ScoreRepo(models)
	self.beatmap_repo = BeatmapRepo(models)
	self.friends_repo = FriendsRepo(models)
	self.favourites_repo = FavouritesRepo(models)
	self.stats_repo = StatsRepo(models)
	self.replay_repo = ReplayRepo(models)
end

return Repos
