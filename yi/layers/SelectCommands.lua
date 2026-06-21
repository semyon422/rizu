local LocationCommands = require("yi.layers.ChartMenus.LocationCommands")

local modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}

local mode_names = {
	chartfile_sets = "sets",
	chartfiles = "files",
	chartmetas = "metas",
	chartdiffs = "diffs",
	chartplays = "plays",
}

---@class yi.layers.ChartMenus.CollectionChoiceValue
---@field path string?
---@field location_id integer?

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

---@param node rizu.library.Collections.TreeNode
---@param choices yi.command_palette.Fuzzy.Candidate[]
---@param prefix string
local function addCollectionChoices(node, choices, prefix)
	for _, item in ipairs(node.items) do
		if item.depth > node.depth then
			local title = prefix .. item.name
			table.insert(choices, {
				title = ("%s (%s)"):format(title, item.count),
				value = {
					path = item.path,
					location_id = item.location_id,
				},
			})

			addCollectionChoices(item, choices, title .. "/")
		end
	end
end

---@param collectionSelector rizu.select.CollectionSelector
---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getCollectionChoices(collectionSelector)
	local tree = collectionSelector.store.root_tree

	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {
		{
			title = ("All collections (%s)"):format(tree.count),
			value = {
				path = nil,
				location_id = nil,
			},
		},
	}
	addCollectionChoices(tree, choices, "")
	return choices
end

---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getBooleanChoices()
	return {
		{
			title = "Enabled",
			value = true,
		},
		{
			title = "Disabled",
			value = false,
		},
	}
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
			id = "select.set_collection",
			title = "Select: Set Collection",
			description = "Changes the selected chart collection",
			arguments = {
				{
					name = "collection",
					type = "string",
					prompt = "Select collection:",
					choices = function()
						return getCollectionChoices(game.collectionSelector)
					end,
				}
			},
			callback = function(args)
				---@type yi.layers.ChartMenus.CollectionChoiceValue
				local collection = args.collection
				game.collectionSelector:selectCollection(collection.path, collection.location_id)
			end
		},
		{
			id = "select.set_locations_in_collections",
			title = "Select: Set Locations in Collections",
			description = "Shows locations as the top collection level",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Locations in collections:",
					choices = getBooleanChoices(),
				}
			},
			callback = function(args)
				game.collectionSelector:setLocationsInCollections(args.enabled)
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
