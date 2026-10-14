local BindingColumn = require("ui.modals.input.BindingColumn")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local UiActions = require("ui.UiActions")

---@class ui.modals.input.Input : ui.ModalView
---@operator call: ui.modals.input.Input
---@field input rizu.api.Input
---@field input_mode string?
---@field columns ui.modals.input.BindingColumn[]
---@field waiting_column ui.modals.input.BindingColumn?
---@field waiting_binding_index integer?
---@field background gui.NineSliceUsage
local Input = ModalView + {}

local MODAL_MAX_WIDTH = 1200
local MODAL_MIN_WIDTH = 700
local MODAL_HEIGHT = 470
local HORIZONTAL_PADDING = 50
local COLUMN_GAP = 10
local MAX_COLUMN_WIDTH = 88
local COLUMN_HEIGHT = 118
local COLUMN_Y = 176

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

---@param input rizu.api.Input
---@param on_close fun()
---@param localization ui.localization.Localization
function Input:new(input, on_close, localization)
	ModalView.new(self)
	self.localization = localization
	self.input = input
	self.columns = {}

	self:setSize(MODAL_MAX_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(false)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.header = self:add(ModalHeader(self.localization:get("song_select.input_bindings"),
		self.localization:get("song_select.input_bindings_subtitle")))

	self.column_list = self:add(FlowContainer({direction = "row", gap = COLUMN_GAP, align = 0.5}))
	self.column_list:setOffset(50, COLUMN_Y)

	self.footer = self:add(ModalFooter(on_close, self.localization:get("settings.close")))
	self.tip_label = self.footer:add(Label({
		font_name = "regular",
		font_size = 18,
		text = self.localization:get("song_select.input_bindings_tip"),
		color = Colors.muted,
		align = "center",
	}))
	self.tip_label:anchorFixed(190, 32, MODAL_MAX_WIDTH - 238, 28)

end

---@param input_mode string?
function Input:setInputMode(input_mode)
	self.waiting_column = nil
	self.waiting_binding_index = nil
	self.column_list:clear()
	self.columns = {}

	self.input_mode = input_mode
	if not input_mode then
		self:setWidth(MODAL_MIN_WIDTH)
		self.tip_label:setWidth(MODAL_MIN_WIDTH - 238)
		self.header.title:setText(self.localization:get("song_select.input_bindings"))
		self.header.subtitle:setText(self.localization:get("song_select.input_bindings_subtitle"))
		self.column_list:fitContent()
		return
	end

	local columns = self.input:getColumns(input_mode)
	local mode_text = input_mode:gsub("key", "K"):gsub("scratch", "S")
	self.header.title:setText(self.localization:get("song_select.input_bindings"))
	self.header.subtitle:setText(self.localization:get("song_select.input_bindings_for") .. mode_text .. ".")
	local count = #columns
	local natural_content_width = count * MAX_COLUMN_WIDTH + math.max(0, count - 1) * COLUMN_GAP
	local modal_width = math.min(MODAL_MAX_WIDTH, math.max(MODAL_MIN_WIDTH,
		natural_content_width + HORIZONTAL_PADDING * 2))
	local content_width = modal_width - HORIZONTAL_PADDING * 2
	self:setWidth(modal_width)
	self.tip_label:setWidth(modal_width - 238)
	local width = math.min(MAX_COLUMN_WIDTH,
		(content_width - COLUMN_GAP * math.max(0, count - 1)) / math.max(1, count))
	for _, column in ipairs(columns) do
		local view = BindingColumn(column, self.input, input_mode, width, function(selected, binding_index)
			self:waitForKey(selected, binding_index)
		end)
		self.columns[#self.columns + 1] = self.column_list:add(view)
	end
	self.column_list:fitContent()
	self.column_list:setOffset((modal_width - self.column_list.width) / 2, COLUMN_Y)
end

---@param column ui.modals.input.BindingColumn
---@param binding_index integer?
function Input:waitForKey(column, binding_index)
	if self.waiting_column then
		self.waiting_column:setWaiting(false)
	end
	self.waiting_column = column
	self.waiting_binding_index = binding_index or 1
	column:setWaiting(true, self.waiting_binding_index)
end

---@param inputs gui.Inputs
function Input:onHandleInputs(inputs)
	if self.waiting_column and inputs:consumeActionJustPressed(UiActions.cancel) then
		self.waiting_column:setWaiting(false)
		self.waiting_column = nil
		self.waiting_binding_index = nil
	end
end

---@param e gui.KeyDownEvent
function Input:onKeyDown(e)
	if e.key == "escape" then
		-- Leave cancel available for ModalManager.
		return
	end
	-- Gameplay matches keyboard inputs by scancode (see LoopEvents), so bind
	-- the scancode: the key name depends on the layout (right alt is "mode",
	-- dead keys are "unknown") and would never match in game.
	local key = e.scancode or e.key
	if not key then return end
	if not MODIFIER_KEYS[key]
		and (e.control_pressed or e.shift_pressed or e.alt_pressed or e.super_pressed)
	then
		-- Input bindings do not support key combinations.
		return
	end
	if not self.waiting_column or e.is_repeated then
		return
	end
	local column = self.waiting_column
	local binding_index = self.waiting_binding_index or 1
	self.waiting_column = nil
	self.waiting_binding_index = nil
	column:setWaiting(false)
	self.input:setBinding(column.input_mode, column.column, binding_index, key, e.device or "keyboard", e.device_id or 1)

	for index, candidate in ipairs(self.columns) do
		if candidate == column and self.columns[index + 1] then
			self:waitForKey(self.columns[index + 1])
			break
		end
	end
	return true
end

function Input:show()
	self:setInputMode(self.input:getInputMode())
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Input:hide()
	if self.waiting_column then
		self.waiting_column:setWaiting(false)
		self.waiting_column = nil
		self.waiting_binding_index = nil
	end
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Input:receive()
	self:setInputMode(self.input:getInputMode())
end

function Input:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Input
