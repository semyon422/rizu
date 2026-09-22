local NoteSkins = require("ui.modals.note_skins.NoteSkins")

local test = {}

---@param t testing.T
function test.selects_and_persists_skin(t)
	local selected
	local skin = {path = "userdata/dlc/skins_rizu/example.skin.lua"}
	local modal = {
		items = {skin},
		input_mode = "4key",
		game = {
			settings = {
				getStringMap = function() return {} end,
				setStringMap = function(_, key, paths) selected = {key, paths["mania/4key"]} end,
			},
		},
		list = {},
	}

	NoteSkins.select(modal, 1)
	t:tdeq(selected, {"gameplay.skins", skin.path})
	t:eq(modal.list.selected_path, skin.path)
end

return test
