local Colors = require("ui.Colors")
local Form = require("ui.views.form.Form")
local FormatMultiSelect = require("ui.views.form.FormatMultiSelect")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local InputModeMultiSelect = require("ui.views.form.InputModeMultiSelect")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.filters.Filters : ui.ModalView
---@operator call: ui.modals.filters.Filters
---@field charts rizu.api.Charts
---@field unsubscribe fun()?
---@field form ui.views.form.Form
---@field played ui.views.form.SegmentedControl
---@field scratch ui.views.form.SegmentedControl
---@field formats ui.views.form.FormatMultiSelect
---@field original_input_modes ui.views.form.InputModeMultiSelect
---@field actual_input_modes ui.views.form.InputModeMultiSelect
---@field lamp ui.views.form.Textbox
local Filters = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 643
local CONTENT_X = 50
local CONTENT_Y = 88
local OPTIONS = {"any", "yes", "no"}

---@param charts rizu.api.Charts
---@param popup_container ui.views.PopupContainer
---@param localization ui.localization.Localization
function Filters:new(charts, popup_container, localization)
	ModalView.new(self)
		local function formatValue(value) return localization:get("song_select.filter_" .. value) end
	self.charts = charts
	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt,
		sprites.nineslice_modal_t,
		sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l,
		sprites.nineslice_modal_c,
		sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb,
		sprites.nineslice_modal_b,
		sprites.nineslice_modal_rb,
	})

	self:add(Label({
		font_name = "bold",
		font_size = 32,
		text = localization:get("song_select.filters_title"),
	})):anchorFixed(CONTENT_X, 28, MODAL_WIDTH - CONTENT_X * 2, 40)

	self.form = Form({direction = "column", gap = 18})
	self.form:setOffset(CONTENT_X, CONTENT_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))

	self.played = self.form:add(SegmentedControl({
		label = localization:get("song_select.played"),
		options = OPTIONS,
		value = "any",
		format = formatValue,
		on_change = function(value)
			charts:setYesNoFilter("played", value)
		end,
	}))
	self.scratch = self.form:add(SegmentedControl({
		label = localization:get("song_select.scratch"),
		options = OPTIONS,
		value = "any",
		format = formatValue,
		on_change = function(value)
			charts:setYesNoFilter("scratch", value)
		end,
	}))
	self.formats = self.form:add(FormatMultiSelect({
		label = localization:get("song_select.format"),
		on_change = function(values)
			charts:setFilterValues("format", values)
		end,
	}))
	self.original_input_modes = self.form:add(InputModeMultiSelect({
		label = localization:get("song_select.original_input_mode"),
		popup_container = popup_container,
		on_change = function(values)
			charts:setFilterValues("original_input_mode", values)
		end,
	}))
	self.actual_input_modes = self.form:add(InputModeMultiSelect({
		label = localization:get("song_select.actual_input_mode"),
		popup_container = popup_container,
		on_change = function(values)
			charts:setFilterValues("actual_input_mode", values)
		end,
	}))
	self.lamp = self.form:add(Textbox({
		label = localization:get("song_select.lamp_filter"),
		width = MODAL_WIDTH - CONTENT_X * 2,
		placeholder = "miss<3",
		live = true,
		on_change = function(text)
			charts:setLampSearch(text)
		end,
	}))
	self.form:fitContent()
end

function Filters:sync()
	local charts = self.charts
	self.played:setValue(charts:getYesNoFilter("played"))
	self.scratch:setValue(charts:getYesNoFilter("scratch"))
	self.formats:setValues(charts:getFilterValues("format"))
	self.original_input_modes:setValues(charts:getFilterValues("original_input_mode"))
	self.actual_input_modes:setValues(charts:getFilterValues("actual_input_mode"))
	self.lamp:setText(charts:getLampSearch())
end

function Filters:load()
	ModalView.load(self)
	self.unsubscribe = self.charts:on("filters_changed", function() self:sync() end)
end

function Filters:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
	ModalView.unload(self)
end

function Filters:show()
	self:sync()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Filters:hide()
	self.original_input_modes:close()
	self.actual_input_modes:close()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Filters:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Filters
