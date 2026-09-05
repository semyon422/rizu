local CollectionSelector = require("ui.modals.collections.CollectionSelector")

local test = {}

---@param t testing.T
function test.filter_matches_labels_and_keeps_selected_value(t)
	local first = {name = "Alpha"}
	local second = {name = "Beta"}
	local modal = {
		options = {
			{label = "Location/Alpha", value = first},
			{label = "Location/Beta", value = second},
		},
		selected_value = second,
		list = {
			setOptions = function(self, options) self.options = options end,
			setSelectedIndex = function(self, index, immediate)
				self.selected_index = index
				self.immediate = immediate
			end,
		},
	}

	CollectionSelector.filter(modal, "BETA")
	t:eq(#modal.filtered_options, 1)
	t:eq(modal.filtered_options[1].value, second)
	t:eq(modal.list.options, modal.filtered_options)
	t:eq(modal.list.selected_index, 1)
	t:eq(modal.list.immediate, true)
end

---@param t testing.T
function test.select_applies_value_and_closes(t)
	local value = {}
	local selected
	local closed = false
	local modal = {
		filtered_options = {{label = "Selected", value = value}},
		on_change = function(new_value) selected = new_value end,
		close = function() closed = true end,
	}

	CollectionSelector.select(modal, 1)
	t:eq(modal.selected_value, value)
	t:eq(selected, value)
	t:eq(closed, true)
end

return test
