local class = require("class")
local digest = require("digest")

---@class sea.ComputeInputLoader
---@operator call: sea.ComputeInputLoader
---@field server_provider sea.IComputeDataProvider
---@field charts_storage sea.IKeyValueStorage
---@field replays_storage sea.IKeyValueStorage
---@field max_chart_size integer
---@field max_replay_size integer
local ComputeInputLoader = class()

ComputeInputLoader.default_max_chart_size = 16 * 1024 * 1024
ComputeInputLoader.default_max_replay_size = 16 * 1024 * 1024

---@param server_provider sea.IComputeDataProvider
---@param charts_storage sea.IKeyValueStorage
---@param replays_storage sea.IKeyValueStorage
function ComputeInputLoader:new(server_provider, charts_storage, replays_storage)
	self.server_provider = server_provider
	self.charts_storage = charts_storage
	self.replays_storage = replays_storage
	self.max_chart_size = self.default_max_chart_size
	self.max_replay_size = self.default_max_replay_size
end

---@param provider sea.IComputeDataProvider
---@param hash string
---@return {name: string, data: string}?
---@return boolean uploaded
---@return string?
function ComputeInputLoader:loadChart(provider, hash)
	local file, server_err = self.server_provider:getChartData(hash)
	local uploaded = false
	local err = server_err
	if not file then
		file, err = provider:getChartData(hash)
		if not file then
			return nil, false, "get chart data: " .. tostring(err)
		end
		uploaded = true
	end
	if type(file.name) ~= "string" or type(file.data) ~= "string" then
		return nil, false, "invalid chart data"
	end
	if #file.data > self.max_chart_size then
		return nil, false, "chart data too large"
	end
	if digest.hash("md5", file.data, true) ~= hash then
		return nil, false, "invalid chart hash"
	end
	if uploaded then
		local ok
		ok, err = self.charts_storage:set(hash, file.data)
		if not ok then
			return nil, false, "store chart data: " .. tostring(err)
		end
	end
	return file, uploaded
end

---@param provider sea.IComputeDataProvider
---@param hash string
---@return string?
---@return boolean uploaded
---@return string?
function ComputeInputLoader:loadReplay(provider, hash)
	local data, server_err = self.server_provider:getReplayData(hash)
	local uploaded = false
	local err = server_err
	if not data then
		data, err = provider:getReplayData(hash)
		if not data then
			return nil, false, "get replay data: " .. tostring(err)
		end
		uploaded = true
	end
	if type(data) ~= "string" then
		return nil, false, "invalid replay data"
	end
	if #data > self.max_replay_size then
		return nil, false, "replay data too large"
	end
	if digest.hash("md5", data, true) ~= hash then
		return nil, false, "invalid replay hash"
	end
	if uploaded then
		local ok
		ok, err = self.replays_storage:set(hash, data)
		if not ok then
			return nil, false, "store replay data: " .. tostring(err)
		end
	end
	return data, uploaded
end

return ComputeInputLoader
