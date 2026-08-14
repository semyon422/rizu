local Settings = require("rizu.config.Settings")

local modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}

local mode_names = {
	chartfile_sets = "sets",
	chartfiles = "files",
	chartmetas = "metas",
	chartdiffs = "diffs",
	chartplays = "plays",
}

---@class rizu.commands.CollectionChoiceValue
---@field path string?
---@field location_id integer?

---@return rizu.command.Fuzzy.Candidate[] choices
local function getModeChoices()
	---@type rizu.command.Fuzzy.Candidate[]
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
---@param choices rizu.command.Fuzzy.Candidate[]
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
---@return rizu.command.Fuzzy.Candidate[] choices
local function getCollectionChoices(collectionSelector)
	local tree = collectionSelector.store.root_tree

	---@type rizu.command.Fuzzy.Candidate[]
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

---@return rizu.command.Fuzzy.Candidate[] choices
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
---@return rizu.command.Fuzzy.Candidate[] choices
local function getSortChoices(sortModel)
	---@type rizu.command.Fuzzy.Candidate[]
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
---@return rizu.command.Fuzzy.Candidate[] choices
local function getScoreSourceChoices(scoreSelector)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, name in ipairs(scoreSelector.store.scoreSources) do
		table.insert(choices, {
			title = name,
			value = name,
		})
	end
	return choices
end

---@param score_selector rizu.select.ScoreSelector
---@return rizu.command.Fuzzy.Candidate[] choices
local function getScoreFilterChoices(score_selector)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, name in ipairs(score_selector:getScoreFilterNames()) do
		table.insert(choices, {title = name, value = name})
	end
	return choices
end

---@param game sphere.GameController
---@param key "primary_mode"|"secondary_mode"
---@param mode string
local function setSelectionMode(game, key, mode)
	game.settings:setChoice(Settings.keys.select[key], mode)
	game.chartSelector:noDebounceRefresh()
end

---@param game sphere.GameController
---@param key "filterString"|"lampString"
---@param value string
local function setSearchString(game, key, value)
	local setting_key = key == "filterString"
		and Settings.keys.select.filter_string
		or Settings.keys.select.lamp_string
	game.settings:setString(setting_key, value)
	game.chartSelector:noDebounceRefresh()
end

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	local commands = {
		{
			id = "select.random_chart",
			title = "Select: Random Chart",
			description = "Moves selection to a random chart",
			callback = function()
				game.chartSelector:scrollRandom()
			end
		},
		{
			id = "select.pause_preview",
			title = "Select: Pause/Resume Preview",
			description = "Pauses or resumes the current preview audio",
			callback = function()
				game.previewModel:togglePause()
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
				---@type rizu.commands.CollectionChoiceValue
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
				game.settings:setChoice(Settings.keys.select.score_source, args.source)
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
						return getScoreFilterChoices(game.scoreSelector)
					end,
				}
			},
			callback = function(args)
				game.settings:setString(Settings.keys.select.score_filter, args.filter)
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
			id = "select.export_osz",
			title = "Export chart set: To .osz",
			description = "Converts the selected chart set and its resources to an osu! archive",
			callback = function()
				game.chartExporter:exportSelectedSetToOsz(game.chartSelector, false)
			end
		},
		{
			id = "select.export_osz_compiled",
			title = "Export chart set: To .osz (compiled audio)",
			description = "Converts the chart set and compiles each keysounded chart to one WAV file",
			callback = function()
				game.chartExporter:exportSelectedSetToOsz(game.chartSelector, true)
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

	return commands
end
