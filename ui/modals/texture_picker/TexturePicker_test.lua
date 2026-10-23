local TexturePicker = require("ui.modals.texture_picker.TexturePicker")

local test = {}

---@param t testing.T
function test.shows_the_options_and_hands_the_pick_back(t)
	local state = {closed = 0}
	local modal = setmetatable({
		localization = {get = function(_, key) return key end},
		on_close = function() state.closed = state.closed + 1 end,
		header = {title = {setText = function(_, text) state.title = text end}},
		grid = {setItems = function(_, items, selected) state.items, state.selected = items, selected end},
	}, {__index = TexturePicker})
	local picked
	modal:open({
		label = "Arrow texture", type = "texture", options = {"", "arrow"},
		format = function(value) return value == "" and "None" or value end,
		get = function() return "arrow" end,
		set = function() end,
	}, function(value) picked = value end)
	t:eq(state.title, "Arrow texture")
	t:tdeq(state.items, {"", "arrow"})
	t:eq(state.selected, "arrow")
	t:eq(modal:format(""), "None")
	modal:pick("")
	t:eq(state.closed, 1)
	t:eq(picked, "")
end

return test
