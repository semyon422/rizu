local ChartFactory = require("chart.format.notechart.ChartFactory")
local ChartFormat = require("sea.chart.ChartFormat")

---@param name string
---@param inputMode string
---@return sphere.ScoreFilter
local function newInputModeScoreFilter(name, inputMode)
	return {
		name = name,
		check = function(score)
			return score.inputmode == inputMode
		end,
	}
end

---@class sphere.FiltersConfig
---@field notechart (sphere.ChartFilterGroup|sphere.ChartSearchFilter)[]
---@field score sphere.ScoreFilter[]

---@class sphere.ChartConditionFilter
---@field name string
---@field conds rdb.Conditions

---@class sphere.ChartFilterGroup
---@field name string
---@field [integer] sphere.ChartConditionFilter

---@class sphere.ChartSearchFilter
---@field name string
---@field string string?
---@field condition rdb.Conditions?

---@class sphere.ScoreFilter
---@field name string
---@field check (fun(score: sea.Chartplay): boolean)?

local filters = {
	notechart = {
		{
			name = "original input mode",
			{name = "4K", conds = {inputmode__startswith = "4key"}},
			{name = "5K", conds = {inputmode__startswith = "5key"}},
			{name = "6K", conds = {inputmode__startswith = "6key"}},
			{name = "7K", conds = {inputmode__startswith = "7key"}},
			{name = "8K", conds = {inputmode__startswith = "8key"}},
			{name = "9K", conds = {inputmode__startswith = "9key"}},
			{name = "10K", conds = {inputmode__startswith = "10key"}},
		},
		{
			name = "actual input mode",
			{name = "4K", conds = {chartdiff_inputmode__startswith = "4key"}},
			{name = "5K", conds = {chartdiff_inputmode__startswith = "5key"}},
			{name = "6K", conds = {chartdiff_inputmode__startswith = "6key"}},
			{name = "7K", conds = {chartdiff_inputmode__startswith = "7key"}},
			{name = "8K", conds = {chartdiff_inputmode__startswith = "8key"}},
			{name = "9K", conds = {chartdiff_inputmode__startswith = "9key"}},
			{name = "10K", conds = {chartdiff_inputmode__startswith = "10key"}},
		},
		(function()
			local filter = {name = "format"}
			for i, format in ipairs(ChartFormat:list()) do
				filter[i] = {name = format, conds = {format = format}}
			end
			return filter
		end)(),
		(function()
			local filter = {name = "extension"}
			for i, ext in ipairs(ChartFactory.extensions) do
				filter[i] = {name = ext, conds = {chartfile_name__endswith = "." .. ext}}
			end
			return filter
		end)(),
		{
			name = "(not) played",
			{name = "played", conds = {accuracy__isnotnull = true}},
			{name = "not played", conds = {accuracy__isnull = true}},
		},
		{
			name = "scratch",
			{name = "has scratch", conds = {inputmode__contains = "scratch"}},
			{name = "has not scratch", conds = {inputmode__notcontains = "scratch"}},
		},
		{
			name = "chartmeta",
			{name = "has chartmeta", conds = {chartmeta_id__isnotnull = true}},
			{name = "has not chartmeta", conds = {chartmeta_id__isnull = true}},
		},
		{
			name = "chartdiff",
			{name = "has chartdiff", conds = {chartdiff_id__isnotnull = true}},
			{name = "has not chartdiff", conds = {chartdiff_id__isnull = true}},
		},
	},
	score = {
		{name = "No filter"},
		{
			name = "FC",
			check = function(score)
				return score.missCount == 0
			end
		},
		newInputModeScoreFilter("4K", "4key"),
		newInputModeScoreFilter("5K", "5key"),
		newInputModeScoreFilter("6K", "6key"),
		newInputModeScoreFilter("7K", "7key"),
		newInputModeScoreFilter("8K", "8key"),
		newInputModeScoreFilter("9K", "9key"),
		newInputModeScoreFilter("10K", "10key"),
	},
}

return filters
