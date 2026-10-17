local SelectionActions = require("rizu.select.SelectionActions")

local test = {}

---@class rizu.select.SelectionActionsTest.Chartview
---@field location_id integer
---@field dir string

---@class rizu.select.SelectionActionsTest.Location
---@field path string
---@field location_id integer

---@class rizu.select.SelectionActionsTest.OpenCall
---@field location rizu.select.SelectionActionsTest.Location
---@field dir string?

---@param chartview rizu.select.SelectionActionsTest.Chartview?
---@return rizu.select.SelectionActions
---@return rizu.select.SelectionActionsTest.OpenCall[]
local function createActions(chartview)
	---@type rizu.select.SelectionActionsTest.OpenCall[]
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
