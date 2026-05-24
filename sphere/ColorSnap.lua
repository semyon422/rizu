local class = require("class")
local Snap = require("chart.model.convert.Snap")

---@class sphere.ColorSnap
---@operator call: sphere.ColorSnap
local ColorSnap = class()

ColorSnap.default_color = {1, 1, 1}

ColorSnap.snap_colors = {
	[1] = {1, 0, 0},
	[2] = {0, 0, 1},
	[3] = {0.40, 0.17, 0.57},
	[4] = {1, 1, 0},
	[5] = {1, 1, 1},  --
	[6] = {1, 0, 1},
	[7] = {1, 1, 1},  --
	[8] = {1, 0.6, 0.1},
}

---@param denoms integer[]?
function ColorSnap:new(denoms)
	self.snap = Snap(denoms)
end

---@param n number
function ColorSnap:getColor(n)
	local d = self.snap:bestDenom(n)
	return self.snap_colors[d] or self.default_color
end

return ColorSnap
