local class = require("class")

---@class chart.Snap
---@operator call: chart.Snap
local Snap = class()

local default_denoms = {1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16}

---@param denoms integer[]?
function Snap:new(denoms)
	self.denoms = denoms or default_denoms
end

---@param n number
---@return integer
function Snap:bestDenom(n)
	local _delta = math.huge
	local _denom = 1
	for _, denom in ipairs(self.denoms) do
		local delta = math.abs(math.floor(n * denom + 0.5) / denom - n)
		if delta < _delta then
			_denom = denom
			_delta = delta
		end
	end
	return _denom
end

return Snap
