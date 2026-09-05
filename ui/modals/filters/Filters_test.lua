local Filters = require("ui.modals.filters.Filters")

local test = {}

---@param t testing.T
function test.set_filter_updates_both_options_and_refreshes(t)
	local selected = {}
	local applied = 0
	local refreshed = 0
	local filter_model = {
		setFilter = function(_, group, name, active)
			selected[group .. "/" .. name] = active
		end,
		apply = function()
			applied = applied + 1
		end,
	}
	local modal = {
		game = {
			chartSelector = {
				filterModel = filter_model,
				noDebounceRefresh = function()
					refreshed = refreshed + 1
				end,
			},
		},
	}

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "yes")
	t:eq(selected["scratch/has scratch"], true)
	t:eq(selected["scratch/has not scratch"], false)

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "no")
	t:eq(selected["scratch/has scratch"], false)
	t:eq(selected["scratch/has not scratch"], true)

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "any")
	t:eq(selected["scratch/has scratch"], false)
	t:eq(selected["scratch/has not scratch"], false)
	t:eq(applied, 3)
	t:eq(refreshed, 3)
end

return test
