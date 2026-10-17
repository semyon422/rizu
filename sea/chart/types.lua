local valid = require("valid")
local types = require("sea.shared.types")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")
local TimingValues = require("sea.chart.TimingValues")
local InputMode = require("chart.core.InputMode")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

local chart_types = {}

local timings_or_healths = valid.struct({
	name = types.name,
	data = valid.optional(types.number),
})

chart_types.timings = valid.compose(timings_or_healths, Timings.validate)
chart_types.subtimings = valid.compose(timings_or_healths, Subtimings.validate)
chart_types.healths = valid.compose(timings_or_healths, Healths.validate)

local function modifier_value(v)
	if v == nil then
		return true
	end

	local t = type(v)
	if t == "number" then
		return true
	end

	if t ~= "string" then
		return
	end
	---@cast v string

	return #v <= 127
end

-- TODO: better validation
chart_types.modifier = valid.struct({
	id = types.integer,
	version = types.integer,
	value = modifier_value,
})

chart_types.modifiers = valid.array(chart_types.modifier, 10)

---@param v string
function chart_types.inputmode(v)
	if type(v) ~= "string" then
		return
	end

	---@type {[string]: number}
	local _t = {}
	for c, t in v:gmatch("([0-9]+)([a-z]+)") do ---@diagnostic disable-line: no-unknown
		---@cast t string
		_t[t] = tonumber(c)
	end

	return tostring(InputMode(_t)) == v
end

---@param v integer[]
local function is_columns_order(v)
	local t = table.move(v, 1, #v, 1, {})
	table.sort(t)
	for i = 1, #t do
		if i ~= t[i] then
			return
		end
	end
	return true
end
is_columns_order = valid.optional(valid.compose(valid.array(valid.index, 100), is_columns_order))
chart_types.columns_order = is_columns_order

assert(is_columns_order())
assert(is_columns_order({1, 3, 2}))
assert(not is_columns_order({1, 3}))

---@param chartplay sea.Chartplay
---@return true?
---@return string?
local function subtimings_pair(chartplay)
	if not chartplay.timings then
		return true
	end
	local ok, err = TimingValuesFactory:get(chartplay.timings, chartplay.subtimings)
	if not ok then
		return nil, err
	end
	return true
end
chart_types.subtimings_pair = subtimings_pair

function chart_types.timing_values(v)
	return TimingValues.validate(v)
end

chart_types.msd_diff_data = valid.struct({
	overall = types.number,
	stream = types.number,
	jumpstream = types.number,
	handstream = types.number,
	stamina = types.number,
	jackspeed = types.number,
	chordjack = types.number,
	technical = types.number,
})

chart_types.msd_diff_rates = valid.array(types.number, 14)

return chart_types
