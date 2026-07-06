local class = require("class")

---@class chart.IDiffcalc
---@operator call: chart.IDiffcalc
local IDiffcalc = class()

IDiffcalc.name = "IDiffcalc"
IDiffcalc.chartdiff_field = ""

---@param ctx chart.DiffcalcContext
function IDiffcalc:compute(ctx) end

return IDiffcalc
