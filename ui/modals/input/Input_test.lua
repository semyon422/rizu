local Input = require("ui.modals.input.Input")

local test = {}

---@param t testing.T
function test.shows_no_columns_without_an_input_mode(t)
	local texts = {}
	local modal = {
		columns = {},
		column_list = {clear = function() end, fitContent = function() end},
		tip_label = {setWidth = function() end},
		header = {title = {setText = function(_, text) texts.title = text end},
			subtitle = {setText = function(_, text) texts.subtitle = text end}},
		localization = {get = function(_, key) return key end},
		setWidth = function() end,
	}
	Input.setInputMode(modal --[[@as any]], nil)
	t:eq(modal.input_mode, nil)
	t:eq(texts.subtitle, "song_select.input_bindings_subtitle")
end

return test
