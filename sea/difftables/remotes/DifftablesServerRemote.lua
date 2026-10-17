local class = require("class")

---@class sea.DifftablesServerRemote: sea.IServerRemoteContext
---@operator call: sea.DifftablesServerRemote
local DifftablesServerRemote = class()

---@param difftables sea.Difftables
function DifftablesServerRemote:new(difftables)
	self.difftables = difftables
end

---@return sea.Difftable[]
function DifftablesServerRemote:getDifftables()
	return self.difftables:getDifftables()
end

---@param difftable_id integer
---@param since integer
---@param limit integer?
---@return sea.DifftableChartmeta[]?
---@return string?
function DifftablesServerRemote:getDifftableChartmetas(difftable_id, since, limit)
	limit = math.min(math.max(limit or 100, 1), 100)
	return self.difftables:getDifftableChartmetas(self.user, os.time(), difftable_id, true, since, limit)
end

return DifftablesServerRemote
