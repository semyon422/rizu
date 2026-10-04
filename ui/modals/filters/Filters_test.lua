local FilterModel = require("rizu.select.FilterModel")
local Filters = require("ui.modals.filters.Filters")

local test = {}

---@param t testing.T
function test.set_filter_updates_both_options_and_notifies(t)
	local selected = {}
	local changed = 0
	local filter_model = FilterModel({configs = {
		select = {selected_filters = selected},
		filters = {notechart = {{
			name = "scratch",
			{name = "has scratch", conds = {has_scratch = true}},
			{name = "has not scratch", conds = {has_scratch = false}},
		}}},
	}})
	filter_model:onChanged(function(event)
		t:eq(event.type, "filters_changed")
		changed = changed + 1
	end)
	local modal = {
		game = {chartSelector = {filterModel = filter_model}},
	}

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "yes")
	t:eq(selected.scratch["has scratch"], true)
	t:eq(selected.scratch["has not scratch"], false)
	t:tdeq(filter_model.combined_filters, {{"or", {has_scratch = true}}})
	t:eq(changed, 1)

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "no")
	t:eq(selected.scratch["has scratch"], false)
	t:eq(selected.scratch["has not scratch"], true)
	t:tdeq(filter_model.combined_filters, {{"or", {has_scratch = false}}})
	t:eq(changed, 2)

	Filters.setFilter(modal, "scratch", "has scratch", "has not scratch", "any")
	t:eq(selected.scratch["has scratch"], false)
	t:eq(selected.scratch["has not scratch"], false)
	t:tdeq(filter_model.combined_filters, {})
	t:eq(changed, 3)
end

return test
