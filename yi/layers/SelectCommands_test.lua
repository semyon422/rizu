local SelectCommands = require("yi.commands.SelectCommands")

local test = {}

---@return table
local function makeGame()
	local root = {
		count = 3,
		selected = 1,
		depth = 0,
		path = nil,
		location_id = nil,
		name = "/",
		indexes = {},
		items = {},
	}
	local packs = {
		count = 3,
		selected = 1,
		depth = 1,
		path = "packs",
		location_id = 7,
		name = "packs",
		indexes = {},
		items = {root},
	}
	local pack = {
		count = 1,
		selected = 1,
		depth = 2,
		path = "packs/alpha",
		location_id = 7,
		name = "alpha",
		indexes = {},
		items = {packs},
	}
	root.items = {root, packs}
	packs.items[2] = pack

	local game = {
		chartSelector = {
			sortModel = {
				names = {},
			},
		},
		collectionSelector = {
			store = {
				root_tree = root,
			},
			selected_path = nil,
			selected_location_id = nil,
			locations_in_collections = nil,
			selectCollection = function(self, path, location_id)
				self.selected_path = path
				self.selected_location_id = location_id
			end,
			setLocationsInCollections = function(self, enabled)
				self.locations_in_collections = enabled
			end,
		},
	}

	return game
end

---@param commands yi.command_palette.Command[]
---@param id string
---@return yi.command_palette.Command?
local function findCommand(commands, id)
	for _, command in ipairs(commands) do
		if command.id == id then
			return command
		end
	end
end

---@param t testing.T
function test.set_collection_choices_and_callback(t)
	local game = makeGame()
	local command = findCommand(SelectCommands(game), "select.set_collection")

	t:assert(command, "select.set_collection should be registered")

	local choices = command.arguments[1].choices()
	t:eq(#choices, 3)
	t:eq(choices[1].title, "All collections (3)")
	t:eq(choices[2].title, "packs (3)")
	t:eq(choices[3].title, "packs/alpha (1)")

	command.callback({
		collection = choices[3].value,
	})

	t:eq(game.collectionSelector.selected_path, "packs/alpha")
	t:eq(game.collectionSelector.selected_location_id, 7)
end

---@param t testing.T
function test.set_locations_in_collections_choices_and_callback(t)
	local game = makeGame()
	local command = findCommand(SelectCommands(game), "select.set_locations_in_collections")

	t:assert(command, "select.set_locations_in_collections should be registered")

	local choices = command.arguments[1].choices
	t:eq(#choices, 2)
	t:eq(choices[1].title, "Enabled")
	t:eq(choices[1].value, true)
	t:eq(choices[2].title, "Disabled")
	t:eq(choices[2].value, false)

	command.callback({
		enabled = choices[1].value,
	})
	t:eq(game.collectionSelector.locations_in_collections, true)

	command.callback({
		enabled = choices[2].value,
	})
	t:eq(game.collectionSelector.locations_in_collections, false)
end

return test
