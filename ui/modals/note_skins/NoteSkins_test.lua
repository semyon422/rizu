local NoteSkins = require("ui.modals.note_skins.NoteSkins")

local test = {}

---@param t testing.T
function test.selects_and_persists_skin(t)
	local writes = {}
	local selected
	local loaded
	local first = {getPath = function() return "base" end}
	local second = {getPath = function() return "skins/example/skin.ini" end}
	local modal = {
		items = {first, second},
		input_mode = "4key",
		game = {
			noteSkinModel = {
				setDefaultNoteSkin = function(_, input_mode, path) selected = {input_mode, path} end,
				loadNoteSkin = function(_, input_mode) loaded = input_mode end,
			},
			persistence = {configModel = {write = function(_, name) writes[#writes + 1] = name end}},
		},
		list = {},
	}

	NoteSkins.select(modal, 2)
	t:tdeq(selected, {"4key", "skins/example/skin.ini"})
	t:eq(loaded, "4key")
	t:tdeq(writes, {"settings"})
	t:eq(modal.list.selected_path, "skins/example/skin.ini")
end

return test
