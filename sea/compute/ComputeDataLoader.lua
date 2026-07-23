local class = require("class")
local digest = require("digest")
local ReplayLoader = require("sea.replays.ReplayLoader")

---@class sea.ComputeDataLoader
---@operator call: sea.ComputeDataLoader
local ComputeDataLoader = class()

---@param compute_data_provider sea.IComputeDataProvider
function ComputeDataLoader:new(compute_data_provider)
	self.compute_data_provider = compute_data_provider
	self.charts_size = 0
	self.replays_size = 0
end

---@param hash string
---@return {name: string, data: string}?
---@return string?
function ComputeDataLoader:requireChart(hash)
	local file, err = self.compute_data_provider:getChartData(hash)
	if not file then
		return nil, "get chartfile data: " .. err
	end

	if digest.hash("md5", file.data, true) ~= hash then
		return nil, "invalid hash"
	end

	self.charts_size = self.charts_size + #file.data

	return {
		name = file.name,
		data = file.data,
	}
end

---@param hash string
---@return {replay: sea.Replay, data: string}?
---@return string?
function ComputeDataLoader:requireReplay(hash)
	local replay_data, err = self.compute_data_provider:getReplayData(hash)
	if not replay_data then
		return nil, "get replay data: " .. (err or "missing error")
	end

	if digest.hash("md5", replay_data, true) ~= hash then
		return nil, "invalid replay hash"
	end

	local replay, err = ReplayLoader.load(replay_data)
	if not replay then
		return nil, "can't load replay: " .. err
	end

	self.replays_size = self.replays_size + #replay_data

	return {
		replay = replay,
		data = replay_data,
	}
end

return ComputeDataLoader
