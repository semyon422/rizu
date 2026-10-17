local IComputeDataProvider = require("sea.compute.IComputeDataProvider")

---@class sea.FakeComputeDataProvider: sea.IComputeDataProvider
---@operator call: sea.FakeComputeDataProvider
local FakeComputeDataProvider = IComputeDataProvider + {}

function FakeComputeDataProvider:new()
	---@type {[string]: {name: string, data: string}}
	self.charts = {}
	---@type {[string]: string}
	self.replays = {}
end

---@param hash string
---@param name string
---@param data string
function FakeComputeDataProvider:addChart(hash, name, data)
	self.charts[hash] = {
		name = name,
		data = data,
	}
end

---@param hash string
---@param data string
function FakeComputeDataProvider:addReplay(hash, data)
	self.replays[hash] = data
end

---@param hash string
---@return {name: string, data: string}?
---@return string?
function FakeComputeDataProvider:getChartData(hash)
	local chart = self.charts[hash]
	if not chart then
		return nil, "chart not found"
	end
	return chart
end

---@param replay_hash string
---@return string?
---@return string?
function FakeComputeDataProvider:getReplayData(replay_hash)
	local replay = self.replays[replay_hash]
	if not replay then
		return nil, "replay not found"
	end
	return replay
end

return FakeComputeDataProvider
