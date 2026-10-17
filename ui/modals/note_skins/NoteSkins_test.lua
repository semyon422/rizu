local NoteSkins = require("ui.modals.note_skins.NoteSkins")
local NoteSkinList = require("ui.modals.note_skins.NoteSkinList")

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

---@param input_mode string
---@param chartview table?
---@param skins table[]
---@param selected table?
---@return table modal
---@return table state
local function new_modal(input_mode, chartview, skins, selected)
	local state = {}
	local modal = {
		skins = {
			getContext = function()
				if chartview and chartview.chartmeta_mode and input_mode ~= "" then
					return chartview.chartmeta_mode, input_mode
				end
			end,
			getList = function(_, gamemode, mode)
				state.listed = {gamemode, mode}
				return skins
			end,
			getSelected = function() return selected end,
			select = function(_, gamemode, mode, skin) state.selected = {gamemode, mode, skin} end,
		},
		localization = {get = function(_, key) return key end},
		list_header = {subtitle = {setText = function(_, text) state.subtitle = text end}},
		list = {setItems = function(_, items, path) state.items, state.path = items, path end},
		edit_button = {setEnabled = function(_, enabled) state.edit_enabled = enabled end},
	}
	return modal, state
end

---@param t testing.T
function test.lists_the_skins_the_registry_offers_and_marks_the_resolved_one(t)
	local skins = {{path = "builtin/mania"}, {path = "skins/a"}, {path = "skins/b"}}
	local modal, state = new_modal("4key", {chartmeta_mode = "mania"}, skins, skins[3])

	NoteSkins.refresh(modal)
	t:tdeq(state.listed, {"mania", "4key"})
	t:eq(state.items, skins)
	t:eq(state.path, "skins/b")
	t:eq(modal.selected_index, 3)
	t:eq(state.subtitle, "song_select.choose_skin_for4key.")
	t:eq(state.edit_enabled, true)
end

---@param t testing.T
function test.osu_family_modes_show_the_osu_skin_title(t)
	local skins = {{path = "skins/a"}}
	for _, mode in ipairs({"osu", "taiko", "catch"}) do
		local modal, state = new_modal("1" .. mode, {chartmeta_mode = mode}, skins, skins[1])
		NoteSkins.refresh(modal)
		t:tdeq(state.listed, {mode, "1" .. mode})
		t:eq(state.subtitle, "song_select.osu_skin", mode)
	end
end

---@param t testing.T
function test.shows_no_skins_without_a_selected_chart(t)
	local modal, state = new_modal("", nil, {{path = "skins/a"}}, nil)
	NoteSkins.refresh(modal)
	t:eq(#state.items, 0)
	t:eq(state.edit_enabled, false)
	t:eq(state.listed, nil)
end

---@param t testing.T
function test.select_stores_the_skin_through_the_registry(t)
	local skins = {{path = "skins/a"}, {path = "skins/b"}}
	local modal, state = new_modal("4key", {chartmeta_mode = "mania"}, skins, skins[1])
	NoteSkins.refresh(modal)

	NoteSkins.select(modal, 2)
	t:tdeq(state.selected, {"mania", "4key", skins[2]})
	t:eq(modal.list.selected_path, "skins/b")
	t:eq(modal.selected_index, 2)
end

---@param t testing.T
function test.list_keeps_its_scroll_when_only_the_selection_changes(t)
	local scrolls = 0
	local list = {items = {}, scrollTo = function() scrolls = scrolls + 1 end}
	local a, b = {path = "a"}, {path = "b"}

	NoteSkinList.setItems(list, {a, b}, "a")
	t:eq(scrolls, 1) -- new items start at the top
	NoteSkinList.setItems(list, {a, b}, "b")
	t:eq(scrolls, 1)
	t:eq(list.selected_path, "b")
	NoteSkinList.setItems(list, {a}, "a")
	t:eq(scrolls, 2)
end

return test
