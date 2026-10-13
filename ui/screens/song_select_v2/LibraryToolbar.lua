local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Resources = require("ui.Resources")
local Dropdown = require("ui.screens.song_select_v2.Dropdown")
local FiltersButton = require("ui.screens.song_select_v2.FiltersButton")
local OnlineButton = require("ui.screens.song_select_v2.OnlineButton")
local SearchField = require("ui.screens.song_select_v2.SearchField")

---Copy of the old toolbar without its strip: the controls sit directly on the blurred background.
---@class ui.screens.song_select_v2.LibraryToolbar : gui.View
---@operator call: ui.screens.song_select_v2.LibraryToolbar
local LibraryToolbar = View + {}

---@param ui ui.UserInterface
---@param popup_container ui.views.PopupContainer
function LibraryToolbar:new(ui, popup_container)
	View.new(self)
	self.ui = ui
	local charts = ui.api.charts

	local controls = self:add(TrackContainer({direction = "row", gap = 10}))
	controls:anchorFill(0, 0, 0, 0)

	self.collection_dropdown = controls:add(Dropdown({
		label = ui.localization:get("song_select.collection"),
		options = {},
		value = nil,
		popup_container = popup_container,
		show_chevron = false,
		on_open = function(dropdown)
			return ui.modal_manager:attachCollectionSelector(dropdown.options, dropdown.value, function(value)
				dropdown:selectOption({label = "", value = value})
			end)
		end,
		on_change = function(item)
			---@cast item rizu.api.Collection
			charts:selectCollection(item)
		end,
	}), 240)

	---@type ui.screens.song_select_v2.DropdownOption[]
	local sort_options = {}
	for _, name in ipairs(charts:getSortNames()) do
		sort_options[#sort_options + 1] = {label = ui.localization:get("song_select.sort_" .. name), value = name}
	end
	self.sort_dropdown = controls:add(Dropdown({
		label = ui.localization:get("song_select.sort"),
		options = sort_options,
		value = charts:getSort(),
		popup_container = popup_container,
		icon = Resources.sprites.icon_layers,
		on_change = function(value)
			---@cast value string
			charts:setSort(value)
		end,
	}), 190)

	controls:add(FiltersButton(ui), 225)
	controls:add(OnlineButton(ui), 190)

	self.search = controls:add(SearchField({
		text = charts:getSearch(),
		placeholder = ui.localization:get("song_select.search_placeholder"),
		on_change = function(text)
			charts:setSearch(text)
		end,
	}), "*")

	-- The collections may be listed after this toolbar is built.
	charts:on("collections_changed", function() self:updateCollections() end)
end

function LibraryToolbar:updateCollections()
	local charts = self.ui.api.charts
	---@type ui.screens.song_select_v2.DropdownOption[]
	local options = {}
	for i, collection in ipairs(charts:getCollections()) do
		local label = collection.kind == "library" and self.ui.localization:get("song_select.all_songs") or collection.label
		options[i] = {label = label, value = collection}
	end
	if not options[1] then return end
	self.collection_dropdown:setOptions(options, charts:getSelectedCollection())
end

return LibraryToolbar
