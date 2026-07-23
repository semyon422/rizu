local ModifierModel = require("sphere.models.ModifierModel")

local formats = {"bms", "ksh", "mid", "ojn", "osu", "qua", "sph", "sm"}

---@param value string
---@return boolean valid
---@return string? error_msg
local function validateDeleteConfirm(value)
	if value ~= "DELETE" then
		return false, "Enter DELETE to confirm"
	end
	return true
end

---@return ui.command_palette.Argument confirm_arg
local function getConfirmArgument()
	return {
		name = "confirm",
		type = "string",
		prompt = "Type DELETE to confirm:",
		validate = validateDeleteConfirm,
	}
end

---@param game sphere.GameController
local function refreshSelect(game)
	game.chartSelector:noDebounceRefresh()
end

---@param game sphere.GameController
---@return ui.command_palette.Fuzzy.Candidate[] choices
local function getDiffcalcFieldChoices(game)
	---@type ui.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, field in ipairs(game.difficultyModel.registry.fields) do
		table.insert(choices, {
			title = field,
			value = field,
		})
	end
	return choices
end

---@return ui.command_palette.Fuzzy.Candidate[] choices
local function getFormatChoices()
	---@type ui.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, format in ipairs(formats) do
		table.insert(choices, {
			title = format,
			value = format,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return ui.command_palette.Command[]
return function(game)
	local library = game.library

	return {
		{
			id = "database.update_cache_status",
			title = "Database: Update Cache Status",
			description = "Refreshes chartmeta/chartdiff/chartplay cache status counters",
			callback = function()
				library.statusUpdate:update()
			end,
		},
		{
			id = "database.compute_chartdiffs",
			title = "Database: Compute Missing Chartdiffs",
			description = "Computes missing chartdiffs",
			callback = function()
				library:computeChartdiffs()
			end,
		},
		{
			id = "database.compute_incomplete_chartdiffs",
			title = "Database: Compute Incomplete Chartdiffs",
			description = "Computes incomplete chartdiffs",
			callback = function()
				library:computeIncompleteChartdiffs(false)
			end,
		},
		{
			id = "database.compute_incomplete_chartdiffs_preview",
			title = "Database: Compute Incomplete Chartdiffs With Preview",
			description = "Computes incomplete chartdiffs using preview when possible",
			callback = function()
				library:computeIncompleteChartdiffs(true)
			end,
		},
		{
			id = "database.compute_chartplays",
			title = "Database: Compute Chartplays",
			description = "Computes chartplays",
			callback = function()
				library:computeChartplays()
			end,
		},
		{
			id = "database.reset_diffcalc_field",
			title = "Database: Reset Diffcalc Field",
			description = "Resets one difficulty calculation field",
			arguments = {
				{
					name = "field",
					type = "string",
					prompt = "Select field:",
					choices = function()
						return getDiffcalcFieldChoices(game)
					end,
				},
				getConfirmArgument(),
			},
			callback = function(args)
				library.chartsRepo:resetDiffcalcField(args.field)
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_chart_cache",
			title = "Database: Delete Chart Cache",
			description = "Deletes all chart files, sets, metas, and diffs from cache",
			arguments = {getConfirmArgument()},
			callback = function()
				library.chartfilesRepo:deleteChartfiles()
				library.chartfilesRepo:deleteChartfileSets()
				library.chartsRepo:deleteChartmetas()
				library.chartsRepo:deleteChartdiffs()
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_chartdiffs",
			title = "Database: Delete Chartdiffs",
			description = "Deletes all chartdiffs",
			arguments = {getConfirmArgument()},
			callback = function()
				library.chartsRepo:deleteChartdiffs()
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_modified_chartdiffs",
			title = "Database: Delete Modified Chartdiffs",
			description = "Deletes modified chartdiffs",
			arguments = {getConfirmArgument()},
			callback = function()
				library.chartsRepo:deleteModifiedChartdiffs()
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_selected_chartdiff",
			title = "Database: Delete Selected Chartdiff",
			description = "Deletes the selected chartdiff",
			arguments = {getConfirmArgument()},
			callback = function()
				local chartview = game.chartSelector.chartview
				if chartview and chartview.chartdiff_id then
					library.chartsRepo:deleteChartdiff(chartview.chartdiff_id)
					refreshSelect(game)
				end
			end,
		},
		{
			id = "database.delete_selected_chartdiffs",
			title = "Database: Delete Selected Chart Chartdiffs",
			description = "Deletes all chartdiffs for the selected chart",
			arguments = {getConfirmArgument()},
			callback = function()
				local chartview = game.chartSelector.chartview
				if chartview and chartview.hash and chartview.index then
					library.chartsRepo:deleteChartdiffsByHashIndex(chartview.hash, chartview.index)
					refreshSelect(game)
				end
			end,
		},
		{
			id = "database.reset_chartfile_hashes",
			title = "Database: Reset Chartfile Hashes",
			description = "Resets chartfiles.hash",
			arguments = {getConfirmArgument()},
			callback = function()
				library.chartfilesRepo:resetChartfileHash()
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_chartmetas",
			title = "Database: Delete Chartmetas",
			description = "Deletes all chartmetas",
			arguments = {getConfirmArgument()},
			callback = function()
				library.chartsRepo:deleteChartmetas()
				refreshSelect(game)
			end,
		},
		{
			id = "database.delete_chartmetas_by_format",
			title = "Database: Delete Chartmetas By Format",
			description = "Deletes chartmetas for one format",
			arguments = {
				{
					name = "format",
					type = "string",
					prompt = "Select format:",
					choices = getFormatChoices(),
				},
				getConfirmArgument(),
			},
			callback = function(args)
				library.chartsRepo:deleteChartmetasByFormat(args.format)
				refreshSelect(game)
			end,
		},
		{
			id = "database.compute_selected_diff",
			title = "Database: Compute Selected Diff",
			description = "Computes difficulty for the selected chart",
			callback = function()
				local chartdiff = game.chartSelector.chartview
				if not chartdiff then
					return
				end
				local chart = game.chartSelector:loadChartAbsolute()
				ModifierModel:apply(chartdiff.modifiers, chart)
				game.difficultyModel:compute({}, chart, 1)
			end,
		},
		{
			id = "database.vacuum",
			title = "Database: Vacuum",
			description = "Runs VACUUM on the local game database",
			arguments = {getConfirmArgument()},
			callback = function()
				library.gdb.db:exec("VACUUM;")
			end,
		},
	}
end
