local class = require("class")
local InputMode = require("chart.core.InputMode")
local ColumnsOrder = require("sea.chart.ColumnsOrder")

---@class sea.ModifiersMetaState
---@operator call: sea.ModifiersMetaState
local ModifiersMetaState = class()

---@param inputMode ncdk.InputMode?
function ModifiersMetaState:new(inputMode)
	self.inputMode = InputMode(inputMode)
	self.custom = false
	self:resetOrder()
end

function ModifiersMetaState:resetOrder()
	self.columns_order = ColumnsOrder(self.inputMode)
	self.reorders = 0
end

---@param map {[ncdk2.Column]: ncdk2.Column}
function ModifiersMetaState:applyOrder(map)
	self.reorders = self.reorders + 1
	self.columns_order:apply(map)
end

return ModifiersMetaState
