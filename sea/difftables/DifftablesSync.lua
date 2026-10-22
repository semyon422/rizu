local class = require("class")
local table_util = require("table_util")

---@class sea.DifftablesSync
---@operator call: sea.DifftablesSync
local DifftablesSync = class()

DifftablesSync.limit = 100

---@param remote sea.DifftablesServerRemote
---@param difftables_repo sea.DifftablesRepo
function DifftablesSync:new(remote, difftables_repo)
	self.remote = remote
	self.difftables_repo = difftables_repo
end

local function get_id(v)
	return v.id
end

---@return integer
function DifftablesSync:syncDifftables()
	local difftables_repo = self.difftables_repo

	local difftables_src = self.remote:getDifftables()
	local difftables_dst = difftables_repo:getDifftables()

	local new, old = table_util.array_update(difftables_src, difftables_dst, get_id, get_id)
	local _new = table_util.invert(new)
	local _old = table_util.invert(old)

	local count = 0

	for _, dt in ipairs(difftables_src) do
		if _new[dt.id] then
			difftables_repo:createDifftable(dt)
			count = count + 1
		end
	end
	for _, dt in ipairs(difftables_dst) do
		if _old[dt.id] then
			difftables_repo:deleteDifftable(dt.id)
			count = count + 1
		end
	end

	return count
end

---@return integer
function DifftablesSync:syncDifftableChartmetas()
	local difftables_repo = self.difftables_repo
	local remote = self.remote

	local count = 0
	local difftables = difftables_repo:getDifftables()
	for _, dt in ipairs(difftables) do
		while true do
			local index = difftables_repo:getNextChangeIndex(dt.id)
			local dt_cms = remote:getDifftableChartmetas(dt.id, index, self.limit)
			if not dt_cms or #dt_cms == 0 then
				break
			end
			count = count + #dt_cms
			difftables_repo:insertDifftableChartmetas(dt_cms)
		end
	end

	return count
end

---@return integer? difftables
---@return integer|string chartmetas_or_error
function DifftablesSync:sync()
	self.syncing = true
	local ok, dts, dt_cms = pcall(function()
		return self:syncDifftables(), self:syncDifftableChartmetas()
	end)
	self.syncing = false
	if not ok then
		return nil, tostring(dts)
	end
	return dts, dt_cms
end

return DifftablesSync
