local M = {}

---@param location rizu.library.Location
---@return string title
local function getLocationTitle(location)
	local marker = location.is_internal and "internal" or location.path
	return ("%s: %s (%s)"):format(location.id, location.name, marker)
end

---@param game sphere.GameController
---@param include_internal boolean?
---@return ui.command_palette.Fuzzy.Candidate[] choices
local function getLocationChoices(game, include_internal)
	local locations = game.library.locations
	locations:selectLocations()

	---@type ui.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, location in ipairs(locations.locations) do
		if include_internal or not location.is_internal then
			table.insert(choices, {
				title = getLocationTitle(location),
				value = location.id,
			})
		end
	end
	return choices
end

---@param game sphere.GameController
---@param location_id integer
---@return rizu.library.Location? location
local function getLocation(game, location_id)
	return game.library.locationsRepo:selectLocationById(location_id)
end

---@param game sphere.GameController
local function refreshLocations(game)
	game.library.locations:selectLocations()
	game.chartSelector:noDebounceRefresh()
end

---@param value string
---@return boolean valid
---@return string? error_msg
local function validateNotEmpty(value)
	if value == "" then
		return false, "Value cannot be empty"
	end
	return true
end

---@param game sphere.GameController
---@return ui.command_palette.Command[]
return function(game)
	return {
		{
			id = "locations.create",
			title = "Locations: Create",
			description = "Creates a new chart location",
			arguments = {
				{
					name = "name",
					type = "string",
					prompt = "Enter location name:",
					validate = validateNotEmpty,
				},
				{
					name = "path",
					type = "string",
					prompt = "Enter location path:",
					validate = validateNotEmpty,
				},
			},
			callback = function(args)
				local locations = game.library.locations
				local location = game.library.locationsRepo:insertLocation({
					path = args.path,
					name = args.name,
					is_relative = false,
					is_internal = false,
				})
				locations:updateLocationPath(location, args.path)
				refreshLocations(game)
			end,
		},
		{
			id = "locations.set_name",
			title = "Locations: Set Name",
			description = "Renames an existing location",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, false)
					end,
				},
				{
					name = "name",
					type = "string",
					prompt = "Enter new location name:",
					validate = validateNotEmpty,
				},
			},
			callback = function(args)
				game.library.locationsRepo:updateLocation({
					id = args.location_id,
					name = args.name,
				})
				refreshLocations(game)
			end,
		},
		{
			id = "locations.set_path",
			title = "Locations: Set Path",
			description = "Changes an existing location path",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, false)
					end,
				},
				{
					name = "path",
					type = "string",
					prompt = "Enter new location path:",
					validate = validateNotEmpty,
				},
			},
			callback = function(args)
				local location = getLocation(game, args.location_id)
				if not location then
					return
				end
				game.library.locations:updateLocationPath(location, args.path)
				refreshLocations(game)
			end,
		},
		{
			id = "locations.update_cache",
			title = "Locations: Update Cache",
			description = "Scans a location for charts",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, true)
					end,
				},
			},
			callback = function(args)
				game.selectionActions:updateCacheLocation(args.location_id)
			end,
		},
		{
			id = "locations.delete_charts",
			title = "Locations: Delete Chart Cache",
			description = "Deletes cached charts for a location",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, true)
					end,
				},
			},
			callback = function(args)
				game.library.locations:deleteCharts(args.location_id)
				refreshLocations(game)
			end,
		},
		{
			id = "locations.delete",
			title = "Locations: Delete",
			description = "Deletes a non-internal location",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, false)
					end,
				},
			},
			callback = function(args)
				game.library.locations:deleteLocation(args.location_id)
				refreshLocations(game)
			end,
		},
		{
			id = "locations.open_folder",
			title = "Locations: Open Folder",
			description = "Opens a location folder in the file manager",
			arguments = {
				{
					name = "location_id",
					type = "number",
					prompt = "Select location:",
					choices = function()
						return getLocationChoices(game, true)
					end,
				},
			},
			callback = function(args)
				local location = getLocation(game, args.location_id)
				if location then
					game.selectionActions:openLocationDirectory(location)
				end
			end,
		},
	}
end
