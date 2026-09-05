local CollectionList = require("ui.modals.collections.CollectionList")
local Colors = require("ui.Colors")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")

---@class ui.modals.collections.CollectionSelector : ui.ModalView
---@operator call: ui.modals.collections.CollectionSelector
---@field options ui.screens.song_select.DropdownOption[]
---@field filtered_options ui.screens.song_select.DropdownOption[]
local CollectionSelector = ModalView + {}

local MODAL_WIDTH = 680
local MODAL_HEIGHT = 560
local PADDING = 24
local SEARCH_TOP = 24
local SEARCH_HEIGHT = 40
local LIST_TOP = 80

---@param on_close function
function CollectionSelector:new(on_close)
	ModalView.new(self)
	self.on_close = on_close
	self.options = {}
	self.filtered_options = {}
	self.selected_value = nil
	self.on_change = nil
	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.search = self:add(Textbox({
		placeholder = "Search collections and locations...",
		icon = sprites.icon_search,
		blur_on_accept = false,
		blur_on_cancel = false,
		background = true,
		handle_clear_field = false,
		on_change = function(text) self:filter(text) end,
	}))
	self.search:anchorFixed(PADDING, SEARCH_TOP, MODAL_WIDTH - PADDING * 2, SEARCH_HEIGHT)

	self.list = self:add(CollectionList(
		function(index) self.list:setSelectedIndex(index) end,
		function(index) self:select(index) end
	))
	self.list:anchorFixed(PADDING, LIST_TOP, MODAL_WIDTH - PADDING * 2, MODAL_HEIGHT - LIST_TOP - PADDING)
end

---@param options ui.screens.song_select.DropdownOption[]
---@param value any
---@param on_change fun(value: any)
function CollectionSelector:open(options, value, on_change)
	self.options = options
	self.selected_value = value
	self.on_change = on_change
	self.search:setText("")
	self:filter("")
end

---@param query string
function CollectionSelector:filter(query)
	query = query:lower()
	local filtered = {}
	for _, option in ipairs(self.options) do
		if query == "" or option.label:lower():find(query, 1, true) then
			filtered[#filtered + 1] = option
		end
	end
	self.filtered_options = filtered
	self.list:setOptions(filtered)
	local selected_index = 1
	for index, option in ipairs(filtered) do
		if option.value == self.selected_value then
			selected_index = index
			break
		end
	end
	self.list:setSelectedIndex(selected_index, true)
end

function CollectionSelector:focusSearch()
	local inputs = self.screen and self.screen.inputs
	if inputs then
		inputs:setKeyboardFocus(self.search, {control = false, shift = false, alt = false, super = false})
	end
end

function CollectionSelector:show()
	self:setVisible(true)
	self:fadeIn(0.2, "OutCubic")
	self:scaleTo(1, 1, 0.25, "OutQuint")
	self:focusSearch()
end

function CollectionSelector:hide()
	self:transformTo("opacity", 0, 0.15, "InCubic", function() self:setVisible(false) end)
end

function CollectionSelector:close()
	self.on_close()
end

---@param index integer
function CollectionSelector:select(index)
	local option = self.filtered_options[index]
	if not option then return end
	self.selected_value = option.value
	if self.on_change then self.on_change(option.value) end
	self:close()
end

---@param offset integer
function CollectionSelector:moveSelection(offset)
	if #self.filtered_options == 0 then return end
	local index = ((self.list.selected_index - 1 + offset) % #self.filtered_options) + 1
	self.list:setSelectedIndex(index)
end

---@param inputs gui.Inputs
function CollectionSelector:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.down) then
		self:moveSelection(1)
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		self:moveSelection(-1)
	elseif inputs:consumeActionJustPressed(UiActions.accept) then
		self:select(self.list.selected_index)
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self:close()
	end
end

function CollectionSelector:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return CollectionSelector
