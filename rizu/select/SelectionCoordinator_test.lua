local SelectionCoordinator = require("rizu.select.SelectionCoordinator")

local test = {}

---@param t testing.T
function test.activate_preview_loads_preview_and_marks_selection_changed(t)
	local calls = {}
	local coordinator = SelectionCoordinator(
		{
			state = {
				onChanged = {
					add = function() end,
				},
			},
			onChanged = {
				add = function() end,
			},
			setChanged = function()
				table.insert(calls, "changed")
			end,
		},
		{},
		{
			onChanged = {
				add = function() end,
			},
		},
		{},
		{
			load = function()
				table.insert(calls, "preview-load")
			end,
		},
		{}
	)

	coordinator:activatePreview()

	t:tdeq(calls, {
		"preview-load",
		"changed",
	})
end

return test
