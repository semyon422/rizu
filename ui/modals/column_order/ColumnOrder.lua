local ButtonRow = require("ui.views.form.ButtonRow")
local Colors = require("ui.Colors")
local ColumnGrid = require("ui.modals.column_order.ColumnGrid")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---Which keys play which chart columns: swapping by hand, mirroring and shuffling.
---@class ui.modals.column_order.ColumnOrder : ui.ModalView
---@operator call: ui.modals.column_order.ColumnOrder
---@field play rizu.api.Play
---@field form ui.views.form.Form
---@field grid ui.modals.column_order.ColumnGrid?
---@field background gui.NineSliceUsage
local ColumnOrder = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 620
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112

---@type {[rizu.api.Play.ColumnOrderState]: string}
local STATE_KEYS = {
	original = "song_select.column_order_original",
	mirror = "song_select.column_order_mirrored",
	mirror_left = "song_select.column_order_mirrored_left",
	mirror_right = "song_select.column_order_mirrored_right",
	bracketswap = "song_select.column_order_bracketswap",
	shift = "song_select.column_order_shifted",
	custom = "song_select.column_order_custom",
}

---Original, Mirrored, Custom and so on. Also used by the Modifiers modal.
---@param play rizu.api.Play
---@param localization ui.localization.Localization
---@return string
function ColumnOrder.getStateText(play, localization)
	local state, shift = play:getColumnOrderState()
	return localization:get(STATE_KEYS[state], {amount = shift and ("%+d"):format(shift) or ""})
end

---@param play rizu.api.Play
---@param on_back fun()
---@param localization ui.localization.Localization
function ColumnOrder:new(play, on_back, localization)
	ModalView.new(self)
	self.localization = localization
	self.play = play
	self.grid = nil

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

	self:add(ModalHeader(localization:get("song_select.column_order"),
		localization:get("song_select.column_order_subtitle")))
	self:add(ModalFooter(on_back, localization:get("song_select.column_order_back")))

	self.form = Form({direction = "column", gap = 16})
	self.form:setPosition(FORM_X, FORM_Y)
	self:add(self.form)
	self:add(FormSelection(self.form))
end

---Shows the order the game has now, after a button changed it.
function ColumnOrder:refresh()
	local grid = assert(self.grid)
	grid:setOrder(self.play:getColumnOrder())
	grid:setLabel(ColumnOrder.getStateText(self.play, self.localization))
	self.form:fitContent()
end

---@param side rizu.api.Play.ColumnSide?
---@return fun()
function ColumnOrder:mirror(side)
	return function()
		self.play:mirrorColumns(side)
		self:refresh()
	end
end

---@param side rizu.api.Play.ColumnSide?
---@return fun()
function ColumnOrder:randomize(side)
	return function()
		self.play:randomizeColumns(side)
		self:refresh()
	end
end

function ColumnOrder:rebuildForm()
	local play = self.play
	local localization = self.localization
	self.form:clearSelection()
	self.form:clearRows()

	self.grid = self.form:add(ColumnGrid({
		label = ColumnOrder.getStateText(play, localization),
		hint = function(column)
			return localization:get("song_select.column_order_swap", {column = column})
		end,
		order = play:getColumnOrder(),
		width = FORM_WIDTH,
		on_change = function(order)
			play:setColumnOrder(order)
			assert(self.grid):setLabel(ColumnOrder.getStateText(play, localization))
		end,
	}))
	local left = localization:get("song_select.column_order_left")
	local right = localization:get("song_select.column_order_right")
	local all = localization:get("song_select.column_order_all")
	self.form:add(ButtonRow({
		label = localization:get("song_select.column_order_mirror"),
		buttons = {
			{text = left, on_click = self:mirror("left")},
			{text = right, on_click = self:mirror("right")},
			{text = all, on_click = self:mirror()},
		},
	}))
	self.form:add(ButtonRow({
		label = localization:get("song_select.column_order_random"),
		buttons = {
			{text = left, on_click = self:randomize("left")},
			{text = right, on_click = self:randomize("right")},
			{text = all, on_click = self:randomize()},
		},
	}))
	self.form:add(ButtonRow({
		buttons = {{
			text = localization:get("song_select.column_order_reset"),
			on_click = function()
				play:setColumnOrder(nil)
				self:refresh()
			end,
		}},
	}))
	self.form:fitContent()
end

function ColumnOrder:show()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function ColumnOrder:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function ColumnOrder:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return ColumnOrder
