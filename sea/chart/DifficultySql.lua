---SQL of the values a calculator gave to the chartdiffs row of a query, see the chart_difficulties table.
local DifficultySql = {}

---The headline value of a calculator, in the units of the calculator, NULL when there is none.
---@param name string Letters, digits and underscores.
---@return string
function DifficultySql.value(name)
	assert(name:match("^[%w_]+$"), "bad calculator name")
	return ([[(SELECT value / 100.0 FROM chart_difficulties WHERE chartdiff_id = chartdiffs.id AND `key` = 0
AND calc_id = (SELECT id FROM calculators WHERE name = '%s'))]]):format(name)
end

return DifficultySql
