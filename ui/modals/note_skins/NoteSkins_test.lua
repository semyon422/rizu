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
function test.shows_osu_skins_for_native_osu_mode(t)
	---@type {path: string, metadata: {name: string}}[]
	local skins = {
		{path = "skins/first", format = "osu", metadata = {name = "First"}, input_modes = {"4key"}},
		{path = "skins/second", format = "osu", metadata = {name = "Second"}, input_modes = {"4key"}},
	}
	local default_skin = {
		path = "rizu/skin/base/rizu_mania.skin.lua",
		format = "lua",
		metadata = {name = "Rizu Default", gamemode = "mania", input_modes = {"any"}},
	}
	---@type table[]?
	local list_items
	---@type string?
	local list_selected
	---@type string?
	local subtitle
	---@type boolean?
	local edit_enabled
	local modal = {
		game = {
			modifierCoordinator = {state = {inputMode = setmetatable({}, {__tostring = function() return "1osu" end})}},
			chartSelector = {chartview = {format = "osu", chartmeta_mode = "osu"}},
			skinRegistry = {
				getSkins = function() return {default_skin} end,
				getOsuSkins = function() return skins end,
				getOsuSkin = function(_, path)
					for _, skin in ipairs(skins) do
						if skin.path == path then return skin end
					end
				end,
				getSkinForInputMode = function(_, _, _, path)
					for _, skin in ipairs(skins) do
						if skin.path == path then return skin end
					end
				end,
			},
			settings = {getStringMap = function() return {["osu/1osu"] = "skins/second"} end},
		},
		localization = {get = function(_, key) return key end},
		list_header = {subtitle = {setText = function(_, text) subtitle = text end}},
		list = {setItems = function(_, items, selected) list_items, list_selected = items, selected end},
		edit_button = {setEnabled = function(_, enabled) edit_enabled = enabled end},
	}

	NoteSkins.refresh(modal)
	t:eq(modal.input_mode, "1osu")
	t:eq(modal.is_osu_mode, true)
	t:eq(#list_items, 3)
	t:eq(list_items[1].path, default_skin.path)
	t:eq(list_selected, "skins/second")
	t:eq(subtitle, "song_select.osu_skin")
	t:eq(edit_enabled, false)
end

---@param t testing.T
function test.shows_osu_mania_skins_for_mania_regardless_of_chart_format(t)
	local skins = {
		{path = "skins/four-key", format = "osu", name = "Four key", input_modes = {"4key"}},
		{path = "skins/seven-key", format = "osu", name = "Seven key", input_modes = {"7key"}},
	}
	local list_items
	local list_selected
	local selected_settings = { ["mania/4key"] = "skins/four-key" }
	local modal = {
		game = {
			modifierCoordinator = {state = {inputMode = "4key"}},
			chartSelector = {chartview = {format = "stepmania", chartmeta_mode = "mania"}},
			skinRegistry = {
				getSkins = function() return {{
					path = "rizu/skin/base/rizu_mania.skin.lua",
					metadata = {name = "Rizu Default", gamemode = "mania", input_modes = {"any"}},
				}} end,
				getOsuSkins = function() return skins end,
				getOsuSkin = function(_, path)
					for _, skin in ipairs(skins) do
						if skin.path == path then return skin end
					end
				end,
				getSkinForInputMode = function(_, _, _, path)
					for _, skin in ipairs(skins) do
						if skin.path == path then return skin end
					end
				end,
			},
			settings = {
				getStringMap = function() return selected_settings end,
				setStringMap = function(_, _, paths) selected_settings = paths end,
			},
		},
		localization = {get = function(_, key) return key end},
		list_header = {subtitle = {setText = function() end}},
		list = {setItems = function(_, items, selected) list_items, list_selected = items, selected end},
		edit_button = {setEnabled = function() end},
	}

	NoteSkins.refresh(modal)
	t:eq(modal.is_osu_mode, false)
	t:eq(#list_items, 3)
	t:eq(list_items[1].path, "rizu/skin/base/rizu_mania.skin.lua")
	t:eq(list_selected, "skins/four-key")
	NoteSkins.select(modal, 3)
	t:eq(selected_settings["mania/4key"], "skins/seven-key")
end

---@param t testing.T
function test.shows_osu_skin_for_each_osu_chart_mode(t)
	local skins = {
		{path = "skins/first", format = "osu", name = "First", input_modes = {}},
		{path = "skins/second", format = "osu", name = "Second", input_modes = {}},
	}
	local default_skin = {
		path = "rizu/skin/base/rizu_mania.skin.lua",
		metadata = {name = "Rizu Default", gamemode = "mania", input_modes = {"any"}},
	}
	local modes = {
		{chart_mode = "osu", input_mode = "1osu", setting_key = "osu/1osu"},
		{chart_mode = "taiko", input_mode = "1taiko", setting_key = "osu/1taiko"},
		{chart_mode = "catch", input_mode = "1fruits", setting_key = "osu/1fruits"},
	}
	for _, mode in ipairs(modes) do
		local saved_path
		local modal_items
		local modal_selected
		local selected_settings = {[mode.setting_key] = "skins/second"}
		local modal
		modal = {
			game = {
				modifierCoordinator = {state = {inputMode = mode.input_mode}},
				chartSelector = {chartview = {format = "osu", chartmeta_mode = mode.chart_mode}},
				skinRegistry = {
					getSkins = function() return {default_skin} end,
					getOsuSkins = function() return skins end,
					getOsuSkin = function(_, path)
						for _, skin in ipairs(skins) do
							if skin.path == path then return skin end
						end
					end,
					getSkinForInputMode = function(_, _, _, path)
						for _, skin in ipairs(skins) do
						if skin.path == path then return skin end
						end
					end,
				},
				settings = {
					getStringMap = function() return selected_settings end,
					setStringMap = function(_, _, paths)
						selected_settings = paths
						saved_path = paths[mode.setting_key]
					end,
				},
			},
			localization = {get = function(_, key) return key end},
			list_header = {subtitle = {setText = function() end}},
			list = {setItems = function(_, items, selected) modal_items, modal_selected = items, selected end},
			edit_button = {setEnabled = function() end},
		}

		NoteSkins.refresh(modal)
		t:eq(modal.is_osu_mode, true, mode.chart_mode)
		t:eq(#modal_items, 3, mode.chart_mode)
		t:eq(modal_items[1].path, default_skin.path, mode.chart_mode)
		t:eq(modal_selected, "skins/second", mode.chart_mode)
		NoteSkins.select(modal, 2)
		t:eq(saved_path, "skins/first", mode.chart_mode)
	end
end

---@param t testing.T
function test.shows_no_skins_without_a_selected_chart(t)
	local skins = {{path = "skins/first", name = "First", input_modes = {}}}
	local list_items
	local modal = {
		game = {
			modifierCoordinator = {state = {inputMode = ""}},
			skinRegistry = {getOsuSkins = function() return skins end},
			settings = {
				getStringMap = function() return {} end,
				setStringMap = function() end,
			},
		},
		localization = {get = function(_, key) return key end},
		list_header = {subtitle = {setText = function() end}},
		list = {setItems = function(_, items) list_items = items end},
		edit_button = {setEnabled = function() end},
	}

	NoteSkins.refresh(modal)
	t:eq(modal.is_osu_mode, false)
	t:eq(#list_items, 0)
end

---@param t testing.T
function test.selects_and_persists_osu_skin_separately_from_mania(t)
	---@type {[1]: string, [2]: string?}?
	local selected
	local skin = {path = "userdata/dlc/skins_osu/example", format = "osu"}
	local modal = {
		items = {skin},
		input_mode = "1osu",
		is_osu_mode = true,
		osu_skin_setting_key = "osu/1osu",
		edit_button = {setEnabled = function() end},
		game = {
			settings = {
				getStringMap = function() return {} end,
				setStringMap = function(_, key, paths) selected = {key, paths["osu/1osu"]} end,
			},
		},
		list = {},
	}

	NoteSkins.select(modal, 1)
	t:tdeq(selected, {"gameplay.skins", skin.path})
	t:eq(modal.list.selected_path, skin.path)
end

---@param t testing.T
function test.selects_and_persists_osu_skin_for_mania_mode(t)
	local paths = { ["osu/1osu"] = "legacy-skin" }
	local osu_skin = {path = "skins/osu", format = "osu"}
	local modal = {
		items = {osu_skin},
		input_mode = "4key",
		is_osu_mode = false,
		game = {
			settings = {
				getStringMap = function() return paths end,
				setStringMap = function(_, _, updated) paths = updated end,
			},
		},
		list = {},
		edit_button = {setEnabled = function() end},
	}

	NoteSkins.select(modal, 1)
	t:eq(paths["mania/4key"], osu_skin.path)
	t:eq(paths["osu/1osu"], "legacy-skin")
end

function test.selects_and_persists_skin(t)
	---@type {[1]: string, [2]: string?}?
	local selected
	local skin = {path = "userdata/dlc/skins_rizu/example.skin.lua"}
	local modal = {
		items = {skin},
		input_mode = "4key",
		edit_button = {setEnabled = function() end},
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
