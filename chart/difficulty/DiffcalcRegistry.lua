local class = require("class")
local table_util = require("table_util")

---@class chart.DiffcalcRegistry
---@operator call: chart.DiffcalcRegistry
local DiffcalcRegistry = class()

function DiffcalcRegistry:new()
	---@type chart.IDiffcalc[]
	self.diffcalcs = {}
	---@type string[]
	self.fields = {}
end

function DiffcalcRegistry:add(diffcalc)
	table.insert(self.diffcalcs, diffcalc)
	table.insert(self.fields, diffcalc.chartdiff_field)
end

---@param ctx chart.DiffcalcContext
---@param force boolean
function DiffcalcRegistry:compute(ctx, force)
	local chartdiff = ctx.chartdiff
	for _, diffcalc in ipairs(self.diffcalcs) do
		if force or not chartdiff[diffcalc.chartdiff_field] then
			table_util.clear(diffcalc)
			diffcalc:compute(ctx)
		end
	end
end

return DiffcalcRegistry
