local class = require("class")
local VisualPoint = require("chart.refchart.VisualPoint")
local VisualPointReference = require("chart.refchart.VisualPointReference")

---@class refchart.Visual
---@operator call: refchart.Visual
---@field points refchart.VisualPoint[]
local Visual = class()

---@param visual chart.Visual
---@param p_to_index {[chart.AbsolutePoint]: integer}
---@param vp_ref {[chart.VisualPoint]: refchart.VisualPointReference}
---@param l_name string
---@param v_name string
function Visual:new(visual, p_to_index, vp_ref, l_name, v_name)
	self.primaryTempo = visual.primaryTempo
	self.tempoMultiplyTarget = visual.tempoMultiplyTarget

	self.points = {}
	local _points = self.points

	for i, vp in ipairs(visual.points) do
		vp_ref[vp] = VisualPointReference(l_name, v_name, i)
		_points[i] = VisualPoint(
			vp,
			p_to_index[vp.point --[[@as ncdk2.AbsolutePoint]]]
		)
	end
end

return Visual
