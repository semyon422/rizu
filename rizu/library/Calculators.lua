local Settings = require("rizu.config.Settings")
local table_util = require("table_util")

---A difficulty calculator added by a plugin. compute rates unmodded mania charts at rate 1, into the
---chart_difficulties table, see rizu.library.tasks.CalculatorTask. computePlay rates plays, into
---chartplay_ratings, see rizu.library.tasks.PlayRatingTask. Either one may be missing.
---@class rizu.library.Calculator
---@field name string Letters, digits and underscores. Its difficulty setting is "calc:<name>".
---@field version integer Raise it to compute every value again.
---@field keys string[]? Names of the values besides the headline: key i is keys[i]. Only ever append to it.
---@field compute (fun(self: rizu.library.Calculator, ctx: chart.DiffcalcContext, chartmeta: sea.Chartmeta): rizu.library.Calculators.Result)? nil when it doesn't rate the chart.
---@field computePlay (fun(self: rizu.library.Calculator, ctx: chart.DiffcalcContext, score_engine: rizu.ScoreEngine): rizu.library.Calculators.Result)? The played chart, with its modifiers and rate, and the play's events: add the score systems you need with score_engine:addScoreSystem. nil when it doesn't rate the play.

---The headline, or the headline at [0] and other values by their names in keys. nil rates nothing.
---@alias rizu.library.Calculators.Result number|{[0]: number?, [string]: number}|nil

---@class rizu.library.Calculators.Row
---@field key integer
---@field value integer? In hundredths.

---Calculators added by plugins. Plugins add theirs from a `require` package module, which runs in every thread.
local Calculators = {}

---@type rizu.library.Calculator[]
Calculators.list = {}

---@param calc rizu.library.Calculator
function Calculators.add(calc)
	assert(type(calc.name) == "string" and calc.name:match("^[%w_]+$"), "calculator name must be letters, digits and underscores")
	assert(type(calc.version) == "number" and calc.version % 1 == 0, "calculator version must be an integer")
	for i, key in ipairs(calc.keys or {}) do
		assert(type(key) == "string" and table_util.indexof(calc.keys, key) == i, "calculator keys must be unique names")
	end
	for _, other in ipairs(Calculators.list) do
		assert(other.name ~= calc.name, "duplicate calculator: " .. calc.name)
	end
	table.insert(Calculators.list, calc)
	if calc.compute then
		table.insert(Settings.diff_columns, "calc:" .. calc.name)
	end
end

---The rows of a result: key 0 always, so a chart or play rated as nothing is stored too. NaN and infinities,
---which can't be stored as integers, are NULL.
---@param calc rizu.library.Calculator
---@param result rizu.library.Calculators.Result
---@return rizu.library.Calculators.Row[]
function Calculators.toRows(calc, result)
	---@type rizu.library.Calculators.Row[]
	local rows = {}
	---@param key integer
	---@param value number?
	local function add(key, value)
		if value and (value ~= value or math.abs(value) == math.huge) then
			value = nil
		end
		table.insert(rows, {key = key, value = value and math.floor(value * 100 + 0.5)})
	end
	if type(result) ~= "table" then
		add(0, result)
		return rows
	end
	add(0, result[0])
	for i, name in ipairs(calc.keys or {}) do
		if result[name] then
			add(i, result[name])
		end
	end
	for name in pairs(result) do
		assert(name == 0 or table_util.indexof(calc.keys or {}, name), ("%s returned an unknown key: %s"):format(calc.name, name))
	end
	return rows
end

return Calculators
