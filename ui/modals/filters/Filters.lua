local Colors = require("ui.Colors")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local InputModeMultiSelect = require("ui.views.form.InputModeMultiSelect")

---@alias ui.modals.filters.Filters.Value "any"|"yes"|"no"

---@class ui.modals.filters.Filters : ui.ModalView
---@operator call: ui.modals.filters.Filters
---@field game sphere.GameController
---@field form ui.views.form.Form
---@field played ui.views.form.SegmentedControl
---@field scratch ui.views.form.SegmentedControl
---@field original_input_modes ui.views.form.InputModeMultiSelect
---@field actual_input_modes ui.views.form.InputModeMultiSelect
local Filters = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 440
local CONTENT_X = 50
local CONTENT_Y = 88
local OPTIONS = {"any", "yes", "no"}

---@param value ui.modals.filters.Filters.Value
---@return string
local function formatValue(value)
	return value:gsub("^%l", string.upper)
end

---@param filter_model rizu.select.FilterModel
---@param group string
---@param positive string
---@param negative string
---@return ui.modals.filters.Filters.Value
local function getValue(filter_model, group, positive, negative)
	if filter_model:isActive(group, positive) then
		return "yes"
	elseif filter_model:isActive(group, negative) then
		return "no"
	end
	return "any"
end

---@param game sphere.GameController
---@param popup_container ui.views.PopupContainer
function Filters:new(game, popup_container)
	ModalView.new(self)
	self.game = game
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
		text = "Filters",
	})):anchorFixed(CONTENT_X, 28, MODAL_WIDTH - CONTENT_X * 2, 40)

	self.form = Form({direction = "column", gap = 18})
	self.form:setOffset(CONTENT_X, CONTENT_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))

	self.played = self.form:add(SegmentedControl({
		label = "Played",
		options = OPTIONS,
		value = "any",
		format = formatValue,
		on_change = function(value)
			self:setFilter("(not) played", "played", "not played", value)
		end,
	}))
	self.scratch = self.form:add(SegmentedControl({
		label = "Scratch",
		options = OPTIONS,
		value = "any",
		format = formatValue,
		on_change = function(value)
			self:setFilter("scratch", "has scratch", "has not scratch", value)
		end,
	}))
	self.original_input_modes = self.form:add(InputModeMultiSelect({
		label = "Original input mode",
		popup_container = popup_container,
		on_change = function(values)
			self:setInputModes("original input mode", values)
		end,
	}))
	self.actual_input_modes = self.form:add(InputModeMultiSelect({
		label = "Actual input mode",
		popup_container = popup_container,
		on_change = function(values)
			self:setInputModes("actual input mode", values)
		end,
	}))
	self.form:fitContent()
end

---@param group string
---@param positive string
---@param negative string
---@param value ui.modals.filters.Filters.Value
function Filters:setFilter(group, positive, negative, value)
	local chart_selector = self.game.chartSelector
	local filter_model = chart_selector.filterModel
	filter_model:setFilter(group, positive, value == "yes")
	filter_model:setFilter(group, negative, value == "no")
	filter_model:apply()
	chart_selector:noDebounceRefresh()
end

---@param group string
---@param values string[]
function Filters:setInputModes(group, values)
	local chart_selector = self.game.chartSelector
	chart_selector.filterModel:setInputModes(group, values)
	chart_selector.filterModel:apply()
	chart_selector:noDebounceRefresh()
end

function Filters:show()
	local filter_model = self.game.chartSelector.filterModel
	self.played:setValue(getValue(filter_model, "(not) played", "played", "not played"))
	self.scratch:setValue(getValue(filter_model, "scratch", "has scratch", "has not scratch"))
	self.original_input_modes:setValues(filter_model:getInputModes("original input mode"))
	self.actual_input_modes:setValues(filter_model:getInputModes("actual input mode"))
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
