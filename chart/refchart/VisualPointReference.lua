local class = require("class")

---@class refchart.VisualPointReference
---@operator call: refchart.VisualPointReference
local VisualPointReference = class()

---@param layer string
---@param visual string
---@param index integer
function VisualPointReference:new(layer, visual, index)
	self.layer = layer
	self.visual = visual
	self.index = index
end

return VisualPointReference
