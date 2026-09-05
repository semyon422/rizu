local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")
local Image = require("ui.views.Image")
local Dropdown = require("ui.screens.song_select.Dropdown")
local FiltersButton = require("ui.screens.song_select.FiltersButton")
local SearchField = require("ui.screens.song_select.SearchField")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.LibraryToolbar : gui.View
---@operator call: ui.screens.song_select.LibraryToolbar
local LibraryToolbar = View + {}

---@param node rizu.library.Collections.TreeNode
---@param options ui.screens.song_select.DropdownOption[]
---@param prefix string
local function addCollectionOptions(node, options, prefix)
	for _, item in ipairs(node.items) do
		if item.depth > node.depth then
			local label = prefix .. item.name
			options[#options + 1] = {label = label, value = item}
			addCollectionOptions(item, options, label .. "/")
		end
	end
end

---@param ui ui.UserInterface
---@param popup_container ui.views.PopupContainer
function LibraryToolbar:new(ui, popup_container)
	View.new(self)
	self.ui = ui
	local game = ui.game
	local chart_selector = game.chartSelector
	local collection_selector = game.collectionSelector
	local settings = game.settings

	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
		lines = {bottom = true},
	})):anchorFill(0, 0, 0, 0)
	self:add(Image(
		Resources.sprites.song_select_library_toolbar_shadow,
		"fit",
		{Colors.shadow[1], Colors.shadow[2], Colors.shadow[3], 0.27}
	)):anchorFill(0, 0, 0, 0)

	local controls = self:add(TrackContainer({
		direction = "row",
		gap = 8,
		padding = {18, 10, 18, 10},
	}))
	controls:anchorFill(0, 0, 0, 0)

	self.collection_dropdown = controls:add(Dropdown({
		label = "COLLECTION",
		options = {},
		value = nil,
		popup_container = popup_container,
		on_change = function(item)
			---@cast item rizu.library.Collections.TreeNode
			collection_selector:selectCollection(item.path, item.location_id)
		end,
	}), 240)

	---@type ui.screens.song_select.DropdownOption[]
	local sort_options = {}
	for _, name in ipairs(chart_selector.sortModel.names) do
		sort_options[#sort_options + 1] = {label = name:gsub("^%l", string.upper), value = name}
	end
	local sort_key = Settings.keys.select.sort_function
	self.sort_dropdown = controls:add(Dropdown({
		label = "SORT",
		options = sort_options,
		value = settings:getString(sort_key),
		popup_container = popup_container,
		icon = Resources.sprites.icon_layers,
		on_change = function(value)
			---@cast value string
			settings:setString(sort_key, value)
			chart_selector:noDebounceRefresh()
		end,
	}), 150)

	controls:add(FiltersButton(ui), 225)

	local search_key = Settings.keys.select.filter_string
	self.search = controls:add(SearchField({
		text = settings:getString(search_key),
		placeholder = "Search songs, artists, or creators",
		on_change = function(text)
			settings:setString(search_key, text)
			chart_selector:debounceRefresh()
		end,
	}), "*")
end

function LibraryToolbar:updateCollections()
	local selector = self.ui.game.collectionSelector
	local root = selector.store.root_tree
	if not root then return end
	---@type ui.screens.song_select.DropdownOption[]
	local options = {{label = "All songs", value = root}}
	addCollectionOptions(root, options, "")
	self.collection_dropdown:setOptions(options, selector:getSelectedItem() or root)
end

return LibraryToolbar
