local BindingColumn = require("ui.modals.input.BindingColumn")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local InputBinder = require("rizu.input.InputBinder")
local InputDevice = require("rizu.input.InputDevice")
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
---@field game sphere.GameController
---@field binder rizu.InputBinder?
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

local DEBUG_LINES = 8
local DEBUG_X = 0
local DEBUG_Y = -160 -- above the modal, which is no longer clipped

---@param v any
---@return string
local function debugValue(v)
	return v == nil and "nil" or tostring(v)
end

---@param game sphere.GameController
---@param on_close fun()
---@param localization ui.localization.Localization
function Input:new(game, on_close, localization)
	ModalView.new(self)
	self.localization = localization
	self.game = game
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

	-- Temporary: shows every keyboard event this modal receives, to debug keys
	-- (e.g. right alt on Linux/Mac) that cannot be bound.
	self.debug_log = {}
	self.debug_label = self:add(Label({
		font_name = "regular",
		font_size = 14,
		text = "key debug: press keys",
		color = Colors.muted,
	}))
	self.debug_label:setOffset(DEBUG_X, DEBUG_Y)
end

---@param kind string
---@param e gui.KeyboardEvent
---@param result string?
function Input:debugEvent(kind, e, result)
	local line = ("%s key=%s scan=%s rep=%s mods=%s%s%s%s wait=%s -> %s"):format(
		kind,
		debugValue(e.key or e.text),
		debugValue(e.scancode),
		debugValue(e.is_repeated),
		e.control_pressed and "C" or "-",
		e.shift_pressed and "S" or "-",
		e.alt_pressed and "A" or "-",
		e.super_pressed and "G" or "-",
		self.waiting_column and "yes" or "no",
		result or "")
	print("[input debug] " .. line)
	local log = self.debug_log
	log[#log + 1] = line
	if #log > DEBUG_LINES then
		table.remove(log, 1)
	end
	self.debug_label:setText(table.concat(log, "\n"))
end

---@param e gui.KeyUpEvent
function Input:onKeyUp(e)
	self:debugEvent("up  ", e)
end

---@param e gui.TextInputEvent
function Input:onTextInput(e)
	self:debugEvent("text", e)
end

---@param input_mode string?
function Input:setInputMode(input_mode)
	self.waiting_column = nil
	self.waiting_binding_index = nil
	self.column_list:clear()
	self.columns = {}

	if not input_mode or input_mode == "" then
		self.binder = nil
		self:setWidth(MODAL_MIN_WIDTH)
		self.tip_label:setWidth(MODAL_MIN_WIDTH - 238)
		self.header.title:setText(self.localization:get("song_select.input_bindings"))
		self.header.subtitle:setText(self.localization:get("song_select.input_bindings_subtitle"))
		self.column_list:fitContent()
		return
	end

	self.binder = InputBinder(self.game.configModel.configs.input, input_mode)
	local mode_text = input_mode:gsub("key", "K"):gsub("scratch", "S")
	self.header.title:setText(self.localization:get("song_select.input_bindings"))
	self.header.subtitle:setText(self.localization:get("song_select.input_bindings_for") .. mode_text .. ".")
	local count = #self.binder.columns
	local natural_content_width = count * MAX_COLUMN_WIDTH + math.max(0, count - 1) * COLUMN_GAP
	local modal_width = math.min(MODAL_MAX_WIDTH, math.max(MODAL_MIN_WIDTH,
		natural_content_width + HORIZONTAL_PADDING * 2))
	local content_width = modal_width - HORIZONTAL_PADDING * 2
	self:setWidth(modal_width)
	self.tip_label:setWidth(modal_width - 238)
	local width = math.min(MAX_COLUMN_WIDTH,
		(content_width - COLUMN_GAP * math.max(0, count - 1)) / math.max(1, count))
	for _, column in ipairs(self.binder.columns) do
		local view = BindingColumn(column, self.binder, width, function(selected, binding_index)
			self:waitForKey(selected, binding_index)
		end, function()
			self:save()
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

function Input:save()
	self.game.configModel:write("input")
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
		self:debugEvent("down", e, "ignored: escape")
		return
	end
	-- Gameplay matches keyboard inputs by scancode (see LoopEvents), so bind
	-- the scancode: the key name depends on the layout (right alt is "mode",
	-- dead keys are "unknown") and would never match in game.
	local key = e.scancode or e.key
	if not MODIFIER_KEYS[key]
		and (e.control_pressed or e.shift_pressed or e.alt_pressed or e.super_pressed)
	then
		-- Input bindings do not support key combinations.
		self:debugEvent("down", e, "ignored: modifier combination")
		return
	end
	if not self.waiting_column or e.is_repeated then
		self:debugEvent("down", e, "ignored: not waiting or repeat")
		return
	end
	self:debugEvent("down", e, "BOUND " .. debugValue(key))
	local column = self.waiting_column
	local binding_index = self.waiting_binding_index or 1
	self.waiting_column = nil
	self.waiting_binding_index = nil
	column:setWaiting(false)
	column.binder:setKey(column.column, binding_index, key, InputDevice(e.device or "keyboard", e.device_id or 1))
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
		self.waiting_binding_index = nil
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

	local label = self.debug_label
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.rectangle("fill", DEBUG_X - 4, DEBUG_Y - 4, label.width + 8, label.height + 8)
end

return Input
