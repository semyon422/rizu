local SelectionActions = require("rizu.select.SelectionActions")

local test = {}

---@param chartview table?
---@return rizu.select.SelectionActions
---@return table
local function createActions(chartview)
	local calls = {}
	local library = {
		locationsRepo = {
			selectLocationById = function(_, id)
				if id == 1 then
					return {path = "/songs", location_id = 1}
				end
			end,
		},
	}
	local opener = {
		open = function(_, location, dir)
			table.insert(calls, {location = location, dir = dir})
		end,
	}
	local actions = SelectionActions(
		{chartview = chartview},
		library,
		{},
		opener
	)
	return actions, calls
end

---@param t testing.T
function test.open_directory(t)
	local actions, calls = createActions({
		location_id = 1,
		dir = "pack/chart",
	})

	actions:openDirectory()

	t:eq(#calls, 1)
	t:eq(calls[1].location.path, "/songs")
	t:eq(calls[1].dir, "pack/chart")
end

---@param t testing.T
function test.open_selected_location_directory(t)
	local actions, calls = createActions({
		location_id = 1,
		dir = "pack/chart",
	})

	actions:openSelectedLocationDirectory()

	t:eq(#calls, 1)
	t:eq(calls[1].location.path, "/songs")
	t:eq(calls[1].dir, nil)
end

---@param t testing.T
function test.missing_chart_or_location_is_ignored(t)
	local actions, calls = createActions(nil)
	actions:openDirectory()
	t:eq(#calls, 0)

	actions, calls = createActions({location_id = 2, dir = "missing"})
	actions:openDirectory()
	t:eq(#calls, 0)
end

return test
