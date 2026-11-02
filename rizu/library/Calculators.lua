local Settings = require("rizu.config.Settings")

---A difficulty calculator added by a plugin. It rates unmodded mania charts at rate 1, and its values go
---to the chart_difficulties table, see rizu.library.tasks.CalculatorTask.
---@class rizu.library.Calculator
---@field name string Letters, digits and underscores. Its difficulty setting is "calc:<name>".
---@field version integer Raise it to compute every value again.
---@field compute fun(self: rizu.library.Calculator, ctx: chart.DiffcalcContext, chartmeta: sea.Chartmeta): number? nil when it doesn't rate the chart.

---Calculators added by plugins. Plugins add theirs from a `require` package module, which runs in every thread.
local Calculators = {}

---@type rizu.library.Calculator[]
Calculators.list = {}

---@param calc rizu.library.Calculator
function Calculators.add(calc)
	assert(type(calc.name) == "string" and calc.name:match("^[%w_]+$"), "calculator name must be letters, digits and underscores")
	assert(type(calc.version) == "number" and calc.version % 1 == 0, "calculator version must be an integer")
	for _, other in ipairs(Calculators.list) do
		assert(other.name ~= calc.name, "duplicate calculator: " .. calc.name)
	end
	table.insert(Calculators.list, calc)
	table.insert(Settings.diff_columns, "calc:" .. calc.name)
end

return Calculators
