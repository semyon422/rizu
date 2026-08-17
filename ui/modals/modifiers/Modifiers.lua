local Checkbox = require("ui.views.form.Checkbox")
local Colors = require("ui.Colors")
local Dropdown = require("ui.views.form.Dropdown")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Slider = require("ui.views.form.Slider")

---@class ui.modals.modifiers.Modifiers : ui.ModalView
---@operator call: ui.modals.modifiers.Modifiers
---@field game sphere.GameController
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field private form_invalidated boolean
---@field private on_change fun()?
local Modifiers = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 340
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 80

---@param game sphere.GameController
---@param on_change fun()?
function Modifiers:new(game, on_change)
	ModalView.new(self)
	self.game = game
	self.on_change = on_change
	self.form_invalidated = false

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
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
		text = "Gameplay Modifiers",
	})):anchorFixed(FORM_X, 28, FORM_WIDTH, 40)

	self.form = Form({direction = "column", gap = 18})
	self.form:setOffset(FORM_X, FORM_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))
	self:rebuildForm()
end

function Modifiers:changed()
	self.game.modifierSelectModel:change()
	if self.on_change then
		self.on_change()
	end
end

function Modifiers:invalidateForm()
	self.form_invalidated = true
end

function Modifiers:rebuildForm()
	self.form_invalidated = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local game = self.game
	local replay_base = game.replayBase
	local time_rate_model = game.timeRateModel
	local rate_type = replay_base.rate_type
	local range = assert(time_rate_model.range[rate_type], "unknown time rate type")

	self.form:add(Dropdown({
		label = "Time Rate Type",
		options = time_rate_model.types,
		value = rate_type,
		width = FORM_WIDTH,
		format = function(value)
			return value == "exp" and "Exp" or "Linear"
		end,
		on_change = function(value)
			replay_base.rate_type = value
			self:changed()
			self:invalidateForm()
		end,
	}))
	self.form:add(Slider({
		label = "Time Rate",
		value = time_rate_model:get(),
		min = range[1],
		max = range[2],
		step = range[3],
		width = FORM_WIDTH,
		value_format = function(value)
			if rate_type == "linear" then
				return ("%0.2fx"):format(value)
			end
			return ("%+.0f"):format(value)
		end,
		on_change = function(value)
			time_rate_model:set(value)
			self:changed()
		end,
	}))
	self.form:add(Checkbox({
		text = "Constant scroll speed",
		checked = replay_base.const,
		on_change = function(value)
			replay_base.const = value
			self:changed()
		end,
	}))
	self.form:add(Checkbox({
		text = "No Long Notes",
		checked = replay_base.tap_only,
		on_change = function(value)
			replay_base.tap_only = value
			self:changed()
		end,
	}))
	self.form:fitContent()

	if selected_index then
		self.form.selected_index = selected_index
		self.form:syncSelection()
	end
end

---@param dt number
function Modifiers:update(dt)
	if self.form_invalidated then
		self:rebuildForm()
	end
end

function Modifiers:show()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Modifiers:hide()
	self.form:closeActiveDropdown()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Modifiers:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Modifiers
