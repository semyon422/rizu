local Colors = require("ui.Colors")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local TextureGrid = require("ui.views.TextureGrid")

---Picks the value of a skin editor texture property from a grid of its textures.
---@class ui.modals.texture_picker.TexturePicker : ui.ModalView
---@operator call: ui.modals.texture_picker.TexturePicker
---@field property rizu.api.Gameplay.SkinProperty?
---@field on_picked fun(value: any)?
local TexturePicker = ModalView + {}

local WIDTH = 1000
local HEIGHT = 840
local CONTENT_X = 28
local HEADER_HEIGHT = 112
local FOOTER_HEIGHT = 92
local GAP = 20

---@param on_close fun()
---@param localization ui.localization.Localization
function TexturePicker:new(on_close, localization)
	ModalView.new(self)
	self.localization = localization
	self.on_close = on_close
	self.property = nil
	self.on_picked = nil

	self:setSize(WIDTH, HEIGHT):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	self:setOpacity(0):setVisible(false):setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.header = self:add(ModalHeader("", localization:get("gameplay.skin_editor.texture_subtitle")))
	self.grid = self:add(TextureGrid(
		function(value) return self.property and self.property.preview and self.property.preview(value) end,
		function(value) return self:format(value) end,
		function(value) self:pick(value) end
	))
	self.grid:anchorFixed(CONTENT_X, HEADER_HEIGHT + GAP, WIDTH - CONTENT_X * 2,
		HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT - GAP * 2)
	self:add(ModalFooter(on_close, localization:get("settings.close")))
end

---@param value any
---@return string
function TexturePicker:format(value)
	local format = self.property and self.property.format
	return format and format(value) or tostring(value)
end

---@param property rizu.api.Gameplay.SkinProperty A "texture" property.
---@param on_picked fun(value: any)
function TexturePicker:open(property, on_picked)
	self.property = property
	self.on_picked = on_picked
	self.header.title:setText(property.label or self.localization:get(property.label_key))
	self.grid:setItems(property.options or {}, property.get())
end

---@param value any
function TexturePicker:pick(value)
	local on_picked = self.on_picked
	self.on_close()
	if on_picked then on_picked(value) end
end

function TexturePicker:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function TexturePicker:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
		self.grid:clear()
	end)
end

function TexturePicker:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return TexturePicker
