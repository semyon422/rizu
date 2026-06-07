local class = require("class")
local OsuReplayConverter = require("sea.replays.OsuReplayConverter")
local ReplayLoader = require("sea.replays.ReplayLoader")

---@class bancho.adapter.SeaReplayRepo
---@operator call: bancho.adapter.SeaReplayRepo
---@field charts_repo sea.ChartsRepo
---@field users_repo sea.UsersRepo
---@field replays_storage sea.IKeyValueStorage
local SeaReplayRepo = class()

---@param charts_repo sea.ChartsRepo
---@param users_repo sea.UsersRepo
---@param replays_storage sea.IKeyValueStorage
function SeaReplayRepo:new(charts_repo, users_repo, replays_storage)
	self.charts_repo = charts_repo
	self.users_repo = users_repo
	self.replays_storage = replays_storage
	self.osu_replay_converter = OsuReplayConverter()
end

---@param score_id integer
---@param data string
---@return boolean
function SeaReplayRepo:saveReplay(score_id, data)
	return true
end

---@param chartplay sea.Chartplay
---@param score_id integer
---@return string?
function SeaReplayRepo:getReplayFromChartplay(chartplay, score_id)
	local replay_data = self.replays_storage:get(chartplay.replay_hash)
	if not replay_data then
		return nil
	end
	local replay = assert(ReplayLoader.load(replay_data))
	local chartmeta = assert(self.charts_repo.models.chartmetas:find({hash = chartplay.hash, index = chartplay.index}))
	local user = assert(self.users_repo:getUser(chartplay.user_id))
	return self.osu_replay_converter:toOsr(chartmeta, replay, user.name, chartplay, score_id)
end

---@param score_id integer
---@return string?
function SeaReplayRepo:getReplay(score_id)
	local chartplay = self.charts_repo:getChartplay(score_id)
	if not chartplay then
		return nil
	end
	return self:getReplayFromChartplay(chartplay, score_id)
end

return SeaReplayRepo
