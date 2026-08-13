local BindingColumn = require("ui.modals.input.BindingColumn")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local InputBinder = require("rizu.input.InputBinder")
local InputDevice = require("rizu.input.InputDevice")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local UiActions = require("ui.UiActions")

---@class ui.modals.input.Input : ui.ModalView
---@operator call: ui.modals.input.Input
---@field game sphere.GameController
---@field binder rizu.InputBinder?
---@field columns ui.modals.input.BindingColumn[]
---@field waiting_column ui.modals.input.BindingColumn?
---@field background gui.NineSliceUsage
local Input = ModalView + {}

local MODAL_MAX_WIDTH = 1200
local MODAL_MIN_WIDTH = 700
local MODAL_HEIGHT = 400
local HORIZONTAL_PADDING = 50
local COLUMN_GAP = 10
local MAX_COLUMN_WIDTH = 88
local COLUMN_HEIGHT = 118
local COLUMN_Y = (MODAL_HEIGHT - COLUMN_HEIGHT) / 2

local MODIFIER_KEYS = {
	lalt = true,
	ralt = true,
	lctrl = true,
	rctrl = true,
	lgui = true,
	rgui = true,
	lshift = true,
	rshift = true,
}

---@param game sphere.GameController
function Input:new(game)
	ModalView.new(self)
	self.game = game
	self.columns = {}

	self:setSize(MODAL_MAX_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
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

	self.header_label = self:add(Label({
		font_name = "bold",
		font_size = 32,
		text = "Input Bindings",
		align = "center",
	}))
	self.header_label:anchorFixed(HORIZONTAL_PADDING, 35, MODAL_MAX_WIDTH - HORIZONTAL_PADDING * 2, 40)
	self.header_label:setAlignmentX(0.5)

	self.column_list = self:add(FlowContainer({direction = "row", gap = COLUMN_GAP, align = 0.5}))
	self.column_list:setOffset(50, COLUMN_Y)

	self.tip_label = self:add(Label({
		font_name = "regular",
		font_size = 18,
		text = "Left click a frame, then press a key. Right click removes its binding.",
		color = Colors.text_muted,
		align = "center",
	}))
	self.tip_label:anchorFixed(HORIZONTAL_PADDING, 355, MODAL_MAX_WIDTH - HORIZONTAL_PADDING * 2, 28)
	self.tip_label:setAlignmentX(0.5)
end

---@param input_mode string?
function Input:setInputMode(input_mode)
	self.waiting_column = nil
	self.column_list:clear()
	self.columns = {}

	if not input_mode or input_mode == "" then
		self.binder = nil
		self:setWidth(MODAL_MIN_WIDTH)
		self.header_label:setWidth(MODAL_MIN_WIDTH - HORIZONTAL_PADDING * 2)
		self.tip_label:setWidth(MODAL_MIN_WIDTH - HORIZONTAL_PADDING * 2)
		self.header_label:setText("Input Bindings")
		self.column_list:fitContent()
		return
	end

	self.binder = InputBinder(self.game.configModel.configs.input, input_mode)
	local mode_text = input_mode:gsub("key", "K"):gsub("scratch", "S")
	self.header_label:setText("Input Bindings — " .. mode_text)
	local count = #self.binder.columns
	local natural_content_width = count * MAX_COLUMN_WIDTH + math.max(0, count - 1) * COLUMN_GAP
	local modal_width = math.min(MODAL_MAX_WIDTH, math.max(MODAL_MIN_WIDTH,
		natural_content_width + HORIZONTAL_PADDING * 2))
	local content_width = modal_width - HORIZONTAL_PADDING * 2
	self:setWidth(modal_width)
	self.header_label:setWidth(content_width)
	self.tip_label:setWidth(content_width)
	local width = math.min(MAX_COLUMN_WIDTH,
		(content_width - COLUMN_GAP * math.max(0, count - 1)) / math.max(1, count))
	for _, column in ipairs(self.binder.columns) do
		local view = BindingColumn(column, self.binder, width, function(selected)
			self:waitForKey(selected)
		end, function()
			self:save()
		end)
		self.columns[#self.columns + 1] = self.column_list:add(view)
	end
	self.column_list:fitContent()
	self.column_list:setOffset((modal_width - self.column_list.width) / 2, COLUMN_Y)
end

---@param column ui.modals.input.BindingColumn
function Input:waitForKey(column)
	if self.waiting_column then
		self.waiting_column:setWaiting(false)
	end
	self.waiting_column = column
	column:setWaiting(true)
end

function Input:save()
	self.game.configModel:write("input")
end

---@param inputs gui.Inputs
function Input:onHandleInputs(inputs)
	if self.waiting_column and inputs:consumeActionJustPressed(UiActions.cancel) then
		self.waiting_column:setWaiting(false)
		self.waiting_column = nil
	end
end

---@param e gui.KeyDownEvent
function Input:onKeyDown(e)
	if e.key == "escape" then
		-- Leave cancel available for ModalManager.
		return
	end
	if not MODIFIER_KEYS[e.key]
		and (e.control_pressed or e.shift_pressed or e.alt_pressed or e.super_pressed)
	then
		-- Input bindings do not support key combinations.
		return
	end
	if not self.waiting_column or e.is_repeated then
		return
	end
	local column = self.waiting_column
	self.waiting_column = nil
	column:setWaiting(false)
	column.binder:setKey(column.column, 1, e.key, InputDevice(e.device or "keyboard", e.device_id or 1))
	self:save()

	for index, candidate in ipairs(self.columns) do
		if candidate == column and self.columns[index + 1] then
			self:waitForKey(self.columns[index + 1])
			break
		end
	end
	return true
end

---@param chartview rizu.library.LocatedChartview?
---@return string? inputMode
function Input.getInputMode(chartview)
	return chartview and (chartview.chartdiff_inputmode or chartview.inputmode)
end

function Input:show()
	local chartview = self.game.chartSelector.chartview
	self:setInputMode(Input.getInputMode(chartview))
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Input:hide()
	if self.waiting_column then
		self.waiting_column:setWaiting(false)
		self.waiting_column = nil
	end
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

---@param event rizu.select.Event
function Input:receive(event)
	if event.type == "chartview_changed" then
		self:setInputMode(Input.getInputMode(event.chartview))
	end
end

function Input:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Input
