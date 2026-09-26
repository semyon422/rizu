local NoteSkins = require("ui.modals.note_skins.NoteSkins")

local test = {}

---@param t testing.T
function test.edit_starts_skin_editor_only_when_a_skin_is_available(t)
	local edits = 0
	local modal = {
		items = {{path = "skin"}},
		input_mode = "4key",
		on_edit = function() edits = edits + 1 end,
	}

	NoteSkins.editSkin(modal)
	t:eq(edits, 1)

	modal.items = {}
	NoteSkins.editSkin(modal)
	modal.items = {{path = "skin"}}
	modal.input_mode = ""
	NoteSkins.editSkin(modal)
	t:eq(edits, 1)
end

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
