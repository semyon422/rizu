local class = require("class")
local InputMode = require("chart.core.InputMode")
local Resources = require("chart.core.Resources")
local Notes = require("chart.model.notes.Notes")

---@class chart.Chart
---@operator call: chart.Chart
---@field layers {[string]: chart.Layer}
local Chart = class()

function Chart:new()
	self.layers = {}
	self.notes = Notes()
	self.inputMode = InputMode()
	self.resources = Resources()
end

---@return chart.Visual[]
function Chart:getVisuals()
	local visuals = {}
	for _, layer in pairs(self.layers) do
		for _, visual in pairs(layer.visuals) do
			table.insert(visuals, visual)
		end
	end
	return visuals
end

---@param vp chart.VisualPoint
---@return chart.Visual?
function Chart:getVisualByPoint(vp)
	for _, layer in pairs(self.layers) do
		for _, visual in pairs(layer.visuals) do
			if visual.points_map[vp] then
				return visual
			end
		end
	end
end

function Chart:compute()
	for _, layer in pairs(self.layers) do
		layer:compute()
	end
	self.notes:compute()
	assert(self.notes:isValid())
end

return Chart
