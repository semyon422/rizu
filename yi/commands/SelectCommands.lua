local modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}

local mode_names = {
	chartfile_sets = "sets",
	chartfiles = "files",
	chartmetas = "metas",
	chartdiffs = "diffs",
	chartplays = "plays",
}

---@class yi.layers.CollectionChoiceValue
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

---@param scoreSelector rizu.select.ScoreSelector
---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getScoreSourceChoices(scoreSelector)
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, name in ipairs(scoreSelector.store.scoreSources) do
		table.insert(choices, {
			title = name,
			value = name,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getScoreFilterChoices(game)
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, filter in ipairs(game.configModel.configs.filters.score) do
		table.insert(choices, {
			title = filter.name,
			value = filter.name,
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
---@param key "filterString"|"lampString"
---@param value string
local function setSearchString(game, key, value)
	game.configModel.configs.select[key] = value
	game.chartSelector:noDebounceRefresh()
end

---@param game sphere.GameController
---@param ui yi.UserInterface?
---@return yi.command_palette.Command[]
return function(game, ui)
	local commands = {
		{
			id = "select.play",
			title = "Select: Play",
			description = "Starts the selected chart",
			callback = function()
				if ui and game.chartSelector:chartExists() then
					ui:setScreen("chart_loading")
				end
			end
		},
		{
			id = "select.autoplay",
			title = "Select: Autoplay",
			description = "Starts the selected chart with autoplay enabled",
			callback = function()
				if ui and game.chartSelector:chartExists() then
					game.gameplayInteractor.autoplay = true
					ui:setScreen("chart_loading")
				end
			end
		},
		{
			id = "select.open_result",
			title = "Select: Open Result",
			description = "Opens the selected score result",
			callback = function()
				if ui and game.chartSelector:chartExists() and game.scoreSelector.chartplay then
					game.resultController:replayNoteChartAsync("result", game.scoreSelector.chartplay)
					ui:setScreen("result")
				end
			end
		},
		{
			id = "select.random_chart",
			title = "Select: Random Chart",
			description = "Moves selection to a random chart",
			callback = function()
				game.chartSelector:scrollRandom()
			end
		},
		{
			id = "select.stop_preview",
			title = "Select: Stop Preview",
			description = "Stops the current preview audio",
			callback = function()
				game.previewModel:stop()
			end
		},
		{
			id = "select.update_cache",
			title = "Select: Update Cache",
			description = "Updates cache for the selected chart location",
			callback = function()
				game.selectionActions:updateCache(true)
			end
		},
		{
			id = "select.set_search",
			title = "Select: Set Search",
			description = "Sets the chart search text",
			arguments = {
				{
					name = "query",
					type = "string",
					prompt = "Enter chart search:",
				}
			},
			callback = function(args)
				setSearchString(game, "filterString", args.query)
			end
		},
		{
			id = "select.clear_search",
			title = "Select: Clear Search",
			description = "Clears the chart search text",
			callback = function()
				setSearchString(game, "filterString", "")
			end
		},
		{
			id = "select.set_lamp_search",
			title = "Select: Set Lamp Search",
			description = "Sets the lamp search text",
			arguments = {
				{
					name = "query",
					type = "string",
					prompt = "Enter lamp search:",
				}
			},
			callback = function(args)
				setSearchString(game, "lampString", args.query)
			end
		},
		{
			id = "select.clear_lamp_search",
			title = "Select: Clear Lamp Search",
			description = "Clears the lamp search text",
			callback = function()
				setSearchString(game, "lampString", "")
			end
		},
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
				---@type yi.layers.CollectionChoiceValue
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
			id = "select.set_score_source",
			title = "Select: Set Score Source",
			description = "Changes the score list source",
			arguments = {
				{
					name = "source",
					type = "string",
					prompt = "Select score source:",
					choices = function()
						return getScoreSourceChoices(game.scoreSelector)
					end,
				}
			},
			callback = function(args)
				game.configModel.configs.select.scoreSourceName = args.source
				game.scoreSelector:pullScore()
			end
		},
		{
			id = "select.set_score_filter",
			title = "Select: Set Score Filter",
			description = "Changes the score list filter",
			arguments = {
				{
					name = "filter",
					type = "string",
					prompt = "Select score filter:",
					choices = function()
						return getScoreFilterChoices(game)
					end,
				}
			},
			callback = function(args)
				game.configModel.configs.select.scoreFilterName = args.filter
				game.scoreSelector:pullScore()
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
		{
			id = "select.open_modifiers",
			title = "Modal: Open Modifiers",
			description = "Opens gameplay modifiers",
			callback = function()
				if ui then
					ui.modals:open("modifiers")
				end
			end
		},
		{
			id = "select.open_filters",
			title = "Modal: Open Filters",
			description = "Opens select filters",
			callback = function()
				if ui then
					ui.modals:open("filters")
				end
			end
		},
		{
			id = "select.open_input",
			title = "Modal: Open Input",
			description = "Opens input bindings",
			callback = function()
				if ui then
					ui.modals:open("input")
				end
			end
		},
		{
			id = "select.open_noteskins",
			title = "Modal: Open Note Skins",
			description = "Opens note skin selection",
			callback = function()
				if ui then
					ui.modals:open("noteskins")
				end
			end
		},
	}

	return commands
end
