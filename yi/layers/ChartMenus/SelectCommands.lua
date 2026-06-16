local LocationCommands = require("yi.layers.ChartMenus.LocationCommands")

local modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}

local mode_names = {
	chartfile_sets = "sets",
	chartfiles = "files",
	chartmetas = "metas",
	chartdiffs = "diffs",
	chartplays = "plays",
}

---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getModeChoices()
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, mode in ipairs(modes) do
		table.insert(choices, {
			title = mode_names[mode],
			value = mode,
		})
	end
	return choices
end

---@param sortModel rizu.select.SortModel
---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getSortChoices(sortModel)
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, name in ipairs(sortModel.names) do
		table.insert(choices, {
			title = name,
			value = name,
		})
	end
	return choices
end

---@param game sphere.GameController
---@param key "primary_mode"|"secondary_mode"
---@param mode string
local function setSelectionMode(game, key, mode)
	game.configModel.configs.settings.select[key] = mode
	game.chartSelector:noDebounceRefresh()
end

---@param game sphere.GameController
---@return yi.command_palette.Command[]
return function(game)
	local commands = {
		{
			id = "select.set_primary_mode",
			title = "Select: Set Primary Mode",
			description = "Changes the primary selection list mode",
			arguments = {
				{
					name = "mode",
					type = "string",
					prompt = "Select primary mode:",
					choices = getModeChoices(),
				}
			},
			callback = function(args)
				setSelectionMode(game, "primary_mode", args.mode)
			end
		},
		{
			id = "select.set_secondary_mode",
			title = "Select: Set Secondary Mode",
			description = "Changes the secondary selection list mode",
			arguments = {
				{
					name = "mode",
					type = "string",
					prompt = "Select secondary mode:",
					choices = getModeChoices(),
				}
			},
			callback = function(args)
				setSelectionMode(game, "secondary_mode", args.mode)
			end
		},
		{
			id = "select.set_sorting",
			title = "Select: Set Sorting",
			description = "Changes the chart list sorting",
			arguments = {
				{
					name = "sorting",
					type = "string",
					prompt = "Select sorting:",
					choices = getSortChoices(game.chartSelector.sortModel),
				}
			},
			callback = function(args)
				game.chartSelector:setSortFunction(args.sorting)
			end
		},
		{
			id = "select.export_osu",
			title = "Export chart: To .osu",
			description = "Exports the selected chart into userdata/export",
			callback = function()
				game.chartExporter:exportToOsu(game.chartSelector, game.replayBase)
			end
		},
		{
			id = "select.open_chart_folder",
			title = "File: Open chart folder",
			description = "Opens the folder of the selected chart in the file manager",
			callback = function()
				game.selectionActions:openDirectory()
			end
		},
		{
			id = "select.open_location_folder",
			title = "File: Open location folder",
			description = "Opens the folder of the selected location in the file manager",
			callback = function()
				game.selectionActions:openSelectedLocationDirectory()
			end
		},
	}

	for _, command in ipairs(LocationCommands.get(game)) do
		table.insert(commands, command)
	end

	return commands
end
